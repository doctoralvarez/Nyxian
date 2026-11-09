/*
 SPDX-License-Identifier: LicenseRef-EPSL-1.1

 Copyright (C) 2025 - 2026 emexlab

 This file is part of Nyxian.

 Licensed under the emexLabs Public Source License, version 1.1
 (EPSL 1.1).

 Private use and modification are permitted under the license.
 Redistribution of source or binaries, modified or unmodified,
 requires prior written permission from emexLabs.

 External deployment is subject to the source-availability
 requirements and other conditions of the license.

 Provided "AS IS", without warranty, to the extent permitted by law.

 See LICENSE for the full license terms.
*/

/*
 Fork doctoralvarez/Nyxian — version 1.0.0
 Changelog:
  - 1.0.0 (2026-11-09): a real line discipline (ForkLineDiscipline):
    ICANON line editing (⌫ by UTF-8 character, ^W, ^U, ^R, ^V), ^D at an
    empty line is the end of input (read() returns 0), ECHO with ECHOE,
    ECHOKE, ECHOCTL and ECHONL, signals echoed as ^C; without ICANON
    nothing changes (^U still kills). Tested by tools/fork/ldisc_test.
*/

#include <sys/socket.h>
#include <sys/poll.h>
#include <stdio.h>
#include <string.h>
#include <termios.h>
#include <dispatch/dispatch.h>
#include <LindChain/ProcEnvironment/Surface/libkern/patch.h>
#include <LindChain/ProcEnvironment/Surface/libkern/klog.h>
#include <LindChain/ProcEnvironment/Surface/libkern/kpanic.h>
#include <LindChain/ProcEnvironment/Surface/libkern/bsd/proc_info.h>
#include <LindChain/ProcEnvironment/Surface/tty/tty.h>
#include <LindChain/ProcEnvironment/Surface/proc/list.h>
#include <LindChain/ProcEnvironment/Surface/proc/spawn.h>
#include <LindChain/ProcEnvironment/Surface/surface.h>

static dispatch_queue_t tty_signal_queue(void)
{
    static dispatch_queue_t queue;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        queue = dispatch_queue_create("org.emexlabs.nyxian.tty.signal", DISPATCH_QUEUE_SERIAL);
    });
    return queue;
}

void tty_kill(ksurface_tty_t *tty,
              int sig)
{
    pid_t pgrp = tty->pgrp;
    dispatch_async(tty_signal_queue(), ^{
        kinfo_proc_t *kp  = NULL;
        size_t len = 0;
        
        kern_return_t kr = proc_list(kernel_proc_, &kp, &len, PROC_FLV_PGID, pgrp);
        if(kr == KERN_SUCCESS)
        {
            size_t count = len / sizeof(kinfo_proc_t);
            for(size_t i = 0; i < count; i++)
            {
                ksurface_proc_t *session_proc = NULL;
                kr = proc_for_pid(kp[i].kp_proc.p_pid, &session_proc);
                if(kr == KERN_SUCCESS)
                {
                    proc_kill(session_proc, sig);
                    kvo_release(session_proc);
                }
            }
            free(kp);
        }
    });
}

/* BEGIN ForkLineDiscipline */
/*
 * Fork: the line discipline, kept free of the rest of the kernel so CI
 * tests it on its own (tools/fork/ldisc_test). Input flags (ISTRIP, IGNCR,
 * ICRNL, INLCR), signals (ISIG), and with ICANON a line editor: lines reach
 * the program on Enter, VERASE (⌫, also ^H) erases a character (a whole
 * UTF-8 one with IUTF8), VWERASE (^W) a word, VKILL (^U) the line, VREPRINT
 * (^R) shows it again, VLNEXT (^V) takes the next key as it is, VEOF (^D)
 * hands over the line without Enter, or is the end of input on an empty
 * line. ECHO shows what is typed (ECHOE/ECHOKE erase on screen, ECHOCTL
 * shows control keys as ^X, ECHONL echoes Enter without ECHO).
 * Without ICANON, ^U still kills the foreground processes, as before.
 */
typedef struct fork_ldisc_ops {
    void (*slave)(void *ctx, const unsigned char *bytes, size_t n);  /* to the program */
    void (*echo)(void *ctx, const unsigned char *bytes, size_t n);   /* to the screen */
    void (*signal)(void *ctx, int sig);
    void (*eof)(void *ctx);
    void *ctx;
} fork_ldisc_ops_t;

typedef struct fork_ldisc_state {
    unsigned char *line;
    size_t cap;
    size_t *len;
    int *lnext;
} fork_ldisc_state_t;

static int fork_ldisc_is(const struct termios *t, int index, unsigned char c)
{
    cc_t cc = t->c_cc[index];
    return cc != 0 && cc != _POSIX_VDISABLE && c == cc;
}

static void fork_ldisc_echo_byte(const struct termios *t, const fork_ldisc_ops_t *ops, unsigned char c)
{
    if(c == '\n')
    {
        if((t->c_oflag & OPOST) && (t->c_oflag & ONLCR))
        {
            ops->echo(ops->ctx, (const unsigned char *)"\r\n", 2);
        }
        else
        {
            ops->echo(ops->ctx, &c, 1);
        }
    }
    else if((t->c_lflag & ECHOCTL) && (c < 0x20 || c == 0x7f) && c != '\t' && c != '\r')
    {
        unsigned char caret[2] = { '^', (unsigned char)(c == 0x7f ? '?' : c + 0x40) };
        ops->echo(ops->ctx, caret, 2);
    }
    else
    {
        ops->echo(ops->ctx, &c, 1);
    }
}

/* how many cells the byte took on screen when echoed */
static int fork_ldisc_width(const struct termios *t, unsigned char c)
{
    if((c & 0xc0) == 0x80 && (t->c_iflag & IUTF8))
    {
        return 0;  /* UTF-8 continuation byte */
    }
    if((t->c_lflag & ECHOCTL) && (c < 0x20 || c == 0x7f) && c != '\t' && c != '\r')
    {
        return 2;
    }
    return 1;
}

/* erases the last character of the line; returns 0 when the line was empty */
static int fork_ldisc_erase_char(const struct termios *t, const fork_ldisc_state_t *st, const fork_ldisc_ops_t *ops, int visual)
{
    if(*st->len == 0)
    {
        return 0;
    }
    int cells = 0;
    /* a UTF-8 character: the continuation bytes, then its first byte */
    while(*st->len > 0)
    {
        unsigned char c = st->line[--(*st->len)];
        cells += fork_ldisc_width(t, c);
        if(!((t->c_iflag & IUTF8) && (c & 0xc0) == 0x80))
        {
            break;
        }
    }
    if((t->c_lflag & ECHO) && visual)
    {
        for(int i = 0; i < cells; i++)
        {
            ops->echo(ops->ctx, (const unsigned char *)"\b \b", 3);
        }
    }
    return 1;
}

static void fork_ldisc_hand_over(const fork_ldisc_state_t *st, const fork_ldisc_ops_t *ops)
{
    if(*st->len > 0)
    {
        ops->slave(ops->ctx, st->line, *st->len);
    }
    *st->len = 0;
}

static void fork_ldisc_input(const struct termios *t, const fork_ldisc_state_t *st, const fork_ldisc_ops_t *ops, const unsigned char *in, size_t n)
{
    const int canon = (t->c_lflag & ICANON) != 0;
    const int echo = (t->c_lflag & ECHO) != 0;

    for(size_t i = 0; i < n; i++)
    {
        unsigned char c = in[i];

        /* removing high bit on ISTRIP */
        if(t->c_iflag & ISTRIP)
        {
            c &= 0x7f;
        }

        /* ^V: the next key as it is */
        if(canon && *st->lnext)
        {
            *st->lnext = 0;
            if(echo)
            {
                ops->echo(ops->ctx, (const unsigned char *)"\b", 1);
                if(t->c_lflag & ECHOCTL) ops->echo(ops->ctx, (const unsigned char *)"\b", 1);
            }
            goto literal;
        }

        if(t->c_lflag & ISIG)
        {
            int signal = -1;

            if(fork_ldisc_is(t, VINTR, c))
            {
                signal = SIGINT;
            }
            else if(fork_ldisc_is(t, VQUIT, c))
            {
                signal = SIGQUIT;
            }
            else if(fork_ldisc_is(t, VSUSP, c))
            {
                signal = SIGTSTP;
            }
            else if(!canon && fork_ldisc_is(t, VKILL, c))
            {
                signal = SIGKILL;
            }

            if(signal != -1)
            {
                if(!(t->c_lflag & NOFLSH))
                {
                    *st->len = 0;
                }
                if(echo && (t->c_lflag & ECHOCTL) && signal != SIGKILL)
                {
                    fork_ldisc_echo_byte(t, ops, c);
                }
                ops->signal(ops->ctx, signal);
                continue;
            }
        }

        /* if ignore then dont do anything */
        if((t->c_iflag & IGNCR) && c == '\r')
        {
            continue;
        }

        /* handling return to newline translation */
        if((t->c_iflag & ICRNL) && c == '\r')
        {
            c = '\n';
        }
        /* the inverse of the previous translation */
        else if((t->c_iflag & INLCR) && c == '\n')
        {
            c = '\r';
        }

        if(!canon)
        {
            if(echo)
            {
                fork_ldisc_echo_byte(t, ops, c);
            }
            else if((t->c_lflag & ECHONL) && c == '\n')
            {
                fork_ldisc_echo_byte(t, ops, c);
            }
            ops->slave(ops->ctx, &c, 1);
            continue;
        }

        /* the line editor */
        if(fork_ldisc_is(t, VERASE, c) || c == 0x08 || c == 0x7f)
        {
            if(t->c_lflag & ECHOE)
            {
                fork_ldisc_erase_char(t, st, ops, 1);
            }
            else if(fork_ldisc_erase_char(t, st, ops, 0) && echo)
            {
                /* without ECHOE the erase key itself is shown */
                fork_ldisc_echo_byte(t, ops, c);
            }
            continue;
        }
        if((t->c_lflag & IEXTEN) && fork_ldisc_is(t, VWERASE, c))
        {
            while(*st->len > 0 && (st->line[*st->len - 1] == ' ' || st->line[*st->len - 1] == '\t'))
            {
                fork_ldisc_erase_char(t, st, ops, 1);
            }
            while(*st->len > 0 && st->line[*st->len - 1] != ' ' && st->line[*st->len - 1] != '\t')
            {
                fork_ldisc_erase_char(t, st, ops, 1);
            }
            continue;
        }
        if(fork_ldisc_is(t, VKILL, c))
        {
            if((t->c_lflag & ECHOKE) && (t->c_lflag & ECHOE))
            {
                while(fork_ldisc_erase_char(t, st, ops, 1)) {}
            }
            else
            {
                *st->len = 0;
                if(echo)
                {
                    fork_ldisc_echo_byte(t, ops, c);
                    if(t->c_lflag & ECHOK) fork_ldisc_echo_byte(t, ops, '\n');
                }
            }
            continue;
        }
        if((t->c_lflag & IEXTEN) && fork_ldisc_is(t, VREPRINT, c))
        {
            if(echo)
            {
                fork_ldisc_echo_byte(t, ops, c);
                fork_ldisc_echo_byte(t, ops, '\n');
                for(size_t k = 0; k < *st->len; k++)
                {
                    fork_ldisc_echo_byte(t, ops, st->line[k]);
                }
            }
            continue;
        }
        if((t->c_lflag & IEXTEN) && fork_ldisc_is(t, VLNEXT, c))
        {
            *st->lnext = 1;
            if(echo)
            {
                fork_ldisc_echo_byte(t, ops, c);
            }
            continue;
        }
        if(fork_ldisc_is(t, VEOF, c))
        {
            if(*st->len == 0)
            {
                ops->eof(ops->ctx);
            }
            else
            {
                fork_ldisc_hand_over(st, ops);
            }
            continue;
        }

    literal:
        /* full: room is kept for the line end only */
        if(c != '\n' && !fork_ldisc_is(t, VEOL, c) && !fork_ldisc_is(t, VEOL2, c) && *st->len >= st->cap - 1)
        {
            if(t->c_iflag & IMAXBEL) ops->echo(ops->ctx, (const unsigned char *)"\a", 1);
            continue;
        }
        if(*st->len < st->cap)
        {
            st->line[(*st->len)++] = c;
        }
        if(echo || ((t->c_lflag & ECHONL) && c == '\n'))
        {
            fork_ldisc_echo_byte(t, ops, c);
        }
        if(c == '\n' || fork_ldisc_is(t, VEOL, c) || fork_ldisc_is(t, VEOL2, c))
        {
            fork_ldisc_hand_over(st, ops);
        }
    }
}
/* END ForkLineDiscipline */

/* collects what the line discipline produces, written out in blocks */
typedef struct fork_tty_out {
    ksurface_tty_t *tty;
    unsigned char slave[2048];
    size_t slave_n;
    unsigned char echo[2048];
    size_t echo_n;
    int failed;
} fork_tty_out_t;

static int fork_tty_write_all(int fd, const unsigned char *bytes, size_t n)
{
    size_t off = 0;
    while(off < n)
    {
        ssize_t w = write(fd, bytes + off, n - off);
        if(w <= 0)
        {
            return -1;
        }
        off += (size_t)w;
    }
    return 0;
}

static void fork_tty_flush(fork_tty_out_t *out)
{
    if(out->echo_n > 0)
    {
        if(fork_tty_write_all(out->tty->kernelfds[MASTERFD], out->echo, out->echo_n) != 0) out->failed = 1;
        out->echo_n = 0;
    }
    if(out->slave_n > 0)
    {
        /* after the end of input the program's side is closed for writing */
        if(!out->tty->fork_eof &&
           fork_tty_write_all(out->tty->kernelfds[SLAVEFD], out->slave, out->slave_n) != 0) out->failed = 1;
        out->slave_n = 0;
    }
}

static void fork_tty_append(fork_tty_out_t *out, int to_slave, const unsigned char *bytes, size_t n)
{
    unsigned char *buf = to_slave ? out->slave : out->echo;
    size_t *len = to_slave ? &out->slave_n : &out->echo_n;
    while(n > 0)
    {
        if(*len == sizeof(out->slave))
        {
            fork_tty_flush(out);
        }
        size_t room = sizeof(out->slave) - *len;
        size_t take = n < room ? n : room;
        memcpy(buf + *len, bytes, take);
        *len += take;
        bytes += take;
        n -= take;
    }
}

static void fork_tty_to_slave(void *ctx, const unsigned char *bytes, size_t n)
{
    fork_tty_out_t *out = ctx;
    /* echo shown before the program answers it */
    if(out->echo_n > 0) fork_tty_flush(out);
    fork_tty_append(out, 1, bytes, n);
}

static void fork_tty_to_screen(void *ctx, const unsigned char *bytes, size_t n)
{
    fork_tty_append(ctx, 0, bytes, n);
}

static void fork_tty_signal(void *ctx, int sig)
{
    fork_tty_out_t *out = ctx;
    fork_tty_flush(out);
    tty_kill(out->tty, sig);
}

static void fork_tty_eof(void *ctx)
{
    fork_tty_out_t *out = ctx;
    fork_tty_flush(out);
    if(!out->tty->fork_eof)
    {
        /* the program's read() returns 0: the end of input, for good on a socket */
        out->tty->fork_eof = 1;
        shutdown(out->tty->kernelfds[SLAVEFD], SHUT_WR);
    }
}

void tty_ldisc_mode_changed(ksurface_tty_t *tty,
                            const struct termios *old,
                            int flush)
{
    /* the pump thread is suspended by the caller */
    tty->fork_lnext = 0;
    if(flush)
    {
        tty->fork_llen = 0;
        return;
    }
    /* leaving ICANON: what was typed of a line becomes readable at once */
    if((old->c_lflag & ICANON) && !(tty->t.c_lflag & ICANON) && tty->fork_llen > 0)
    {
        if(!tty->fork_eof)
        {
            /* never blocks: the program waiting in this ioctl is the reader */
            (void)send(tty->kernelfds[SLAVEFD], tty->fork_line, tty->fork_llen, MSG_DONTWAIT);
        }
        tty->fork_llen = 0;
    }
}

LIBKERN_DEFINE_PATCHABLE(int, tty_input, (ksurface_tty_t *tty))
{
    ssize_t n = read(tty->kernelfds[MASTERFD], tty->rbuf, TTY_MAX_RD);
    if(n <= 0)
    {
        return -1;
    }

    fork_tty_out_t out;
    out.tty = tty;
    out.slave_n = 0;
    out.echo_n = 0;
    out.failed = 0;

    fork_ldisc_ops_t ops = {
        .slave = fork_tty_to_slave,
        .echo = fork_tty_to_screen,
        .signal = fork_tty_signal,
        .eof = fork_tty_eof,
        .ctx = &out,
    };
    fork_ldisc_state_t st = {
        .line = (unsigned char *)tty->fork_line,
        .cap = sizeof(tty->fork_line),
        .len = &tty->fork_llen,
        .lnext = &tty->fork_lnext,
    };

    fork_ldisc_input(&tty->t, &st, &ops, (const unsigned char *)tty->rbuf, (size_t)n);
    fork_tty_flush(&out);

    return out.failed ? -1 : 0;
}

LIBKERN_DEFINE_PATCHABLE(int, tty_output, (ksurface_tty_t *tty))
{
    ssize_t n = read(tty->kernelfds[SLAVEFD], tty->rbuf, TTY_MAX_RD);
    ssize_t new_n = 0;
    if(n <= 0)
    {
        return -1;
    }
    
    if(!(tty->t.c_oflag & OPOST))
    {
        goto write_out;
    }
    
    for(ssize_t i = 0; i < n; i++)
    {
        uint8_t c = tty->rbuf[i];
        
        if(c == '\n')
        {
            /* very common flag that will fix the terminal inbuilt post process lol */
            if(tty->t.c_oflag & ONLCR)
            {
                tty->obuf[new_n++] = '\r';
                tty->obuf[new_n++] = '\n';
                continue;
            }
        }
        else if(c == '\r')
        {
            /* translate return to newline */
            if(tty->t.c_oflag & OCRNL)
            {
                tty->obuf[new_n++] = '\n';
                continue;
            }
            
            
            if((tty->t.c_oflag & ONOCR) && tty->ws.ws_col == 0)
            {
                continue;
            }
        }
        
        tty->obuf[new_n++] = c;
    }
    
write_out:
    {
        const uint8_t *out = (uint8_t*)((tty->t.c_oflag & OPOST) ? tty->obuf : tty->rbuf);
        ssize_t out_n = (tty->t.c_oflag & OPOST) ? new_n : n;
        
        ssize_t off = 0;
        while(off < out_n)
        {
            ssize_t w = write(tty->kernelfds[MASTERFD], out + off, out_n - off);
            if(w <= 0) return -1;
            off += w;
        }
    }
    
    return 0;
}

LIBKERN_DEFINE_PATCHABLE(void *, tty_pump_thread, (void *arg))
{
    ksurface_tty_t *tty = arg;

    struct pollfd fds[2] = {
        { .fd = tty->kernelfds[MASTERFD], .events = POLLIN },
        { .fd = tty->kernelfds[SLAVEFD] , .events = POLLIN },
    };

    while(tty->alive)
    {
        int r = poll(fds, 2, -1);
        if(r <= 0)
        {
            continue;
        }

        if(fds[0].revents & POLLIN)
        {
            if(tty_input(tty) < 0)
            {
                break;
            }
        }

        if(fds[1].revents & POLLIN)
        {
            if(tty_output(tty) < 0)
            {
                break;
            }
        }
    }

    return NULL;
}

DEFINE_KVOBJECT_MAIN_EVENT_HANDLER(tty)
{
    /* handle size request */
    if(kvarr == NULL)
    {
        return (int64_t)sizeof(ksurface_tty_t);
    }
    
    ksurface_tty_t *tty = (ksurface_tty_t*)kvarr[0];
    
    switch(type)
    {
        case kvObjEventSnapshot:
        case kvObjEventCopy:
            kpanic("attempted to copy or snapshot tty, which is illegal");
        case kvObjEventInit:
        {
            klog_log("tty:init", "initializing tty @ %p", tty);
            
            /* creating pipe */
            int masterpair[2];
            if(socketpair(AF_UNIX, SOCK_STREAM, 0, masterpair) != 0)
            {
                return -1;
            }
            
            /* creating pipe */
            int slavepair[2];
            if(socketpair(AF_UNIX, SOCK_STREAM, 0, slavepair) != 0)
            {
                shutdown(masterpair[1],  SHUT_RDWR);
                close(masterpair[0]);
                close(masterpair[1]);
                return -1;
            }
            
            /* getting unique object pointer */
            struct socket_fdinfo master_si;
            if(proc_pidfdinfo(getpid(), slavepair[0], PROC_PIDFDSOCKETINFO, &master_si, sizeof(struct socket_fdinfo)) <= 0)
            {
                /* notify me, if this happens, apple again had to change something */
                goto out_fail;
            }
            
            struct socket_fdinfo slave_si;
            if(proc_pidfdinfo(getpid(), masterpair[0], PROC_PIDFDSOCKETINFO, &slave_si, sizeof(struct socket_fdinfo)) <= 0)
            {
                /* notify me, if this happens, apple again had to change something */
                goto out_fail;
            }
            
            /* the 2nd fd is always the fd the tty object manages */
            tty->userspacekcid[MASTERFD] = master_si.psi.soi_proto.pri_kern_ctl.kcsi_id;
            tty->userspacekcid[SLAVEFD] = slave_si.psi.soi_proto.pri_kern_ctl.kcsi_id;
            tty->userspacefd[MASTERFD] = masterpair[0];
            tty->userspacefd[SLAVEFD] = slavepair[0];
            tty->kernelfds[MASTERFD] = masterpair[1];
            tty->kernelfds[SLAVEFD] = slavepair[1];
            
            /* inserting own tty file descriptors */
            tty_table_wrlock();
            if(radix_insert(&(ksurface->tty_info.tty), tty->userspacekcid[MASTERFD], tty) != 0)
            {
                tty_table_unlock();
                goto out_fail;
            }
            if(radix_insert(&(ksurface->tty_info.tty), tty->userspacekcid[SLAVEFD], tty) != 0)
            {
                radix_remove(&(ksurface->tty_info.tty), tty->userspacekcid[MASTERFD]);
                tty_table_unlock();
                goto out_fail;
            }
            
            tty_table_unlock();
            
            /* lets start da factory, alive first so the thread cannot see 0 and exit */
            tty->alive = 1;
            if(pthread_create(&tty->pump_thread, NULL, tty_pump_thread, tty) != 0)
            {
                tty->alive = 0;
                goto out_fail_radix;
            }
            
            return 0;
        
        out_fail_radix:
            tty_table_wrlock();
            radix_remove(&(ksurface->tty_info.tty), tty->userspacekcid[MASTERFD]);
            radix_remove(&(ksurface->tty_info.tty), tty->userspacekcid[SLAVEFD]);
            tty_table_unlock();
        out_fail:
            shutdown(tty->kernelfds[SLAVEFD],  SHUT_RDWR);
            shutdown(tty->kernelfds[MASTERFD], SHUT_RDWR);
            close(tty->userspacefd[MASTERFD]);
            close(tty->userspacefd[SLAVEFD]);
            close(tty->kernelfds[MASTERFD]);
            close(tty->kernelfds[SLAVEFD]);
            return -1;
        }
        case kvObjEventDeinit:
            klog_log("tty:deinit", "deinitializing tty @ %p", tty);
            
            /* the thread would go on using this tty after it is freed, see tty_signal_queue */
            if(pthread_equal(pthread_self(), tty->pump_thread))
            {
                kpanic("tty deinitialized on its own pump thread");
            }
            
            /* removing own tty object */
            tty_table_wrlock();
            radix_remove(&(ksurface->tty_info.tty), tty->userspacekcid[MASTERFD]);
            radix_remove(&(ksurface->tty_info.tty), tty->userspacekcid[SLAVEFD]);
            tty_table_unlock();
            
            /* making sure deinit happens, with the threads consent */
            tty->alive = 0;
            
            shutdown(tty->kernelfds[SLAVEFD],  SHUT_RDWR);
            shutdown(tty->kernelfds[MASTERFD], SHUT_RDWR);

            pthread_join(tty->pump_thread, NULL);
            
            close(tty->userspacefd[MASTERFD]);
            close(tty->userspacefd[SLAVEFD]);
            close(tty->kernelfds[MASTERFD]);
            close(tty->kernelfds[SLAVEFD]);
            
            /* fallthrough */
        default:
            return 0;
    }
    
    return 0;
}
