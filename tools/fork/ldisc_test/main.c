/*
 Fork doctoralvarez/Nyxian — version 1.0.0
 Changelog:
  - 1.0.0 (2026-11-09): tests of the tty line discipline. The block between
    BEGIN/END ForkLineDiscipline in tty.c is copied into ldisc.inc by CI
    (or run.sh) and compiled here on its own.
*/

#include <signal.h>
#include <stdio.h>
#include <string.h>
#include <termios.h>
#include <unistd.h>

#ifndef IUTF8
#define IUTF8 0
#endif

#include "ldisc.inc"

typedef struct {
    char slave[4096]; size_t slave_n;
    char echo[4096];  size_t echo_n;
    int sigs[16];     int sig_n;
    int eofs;
} sink_t;

static void s_slave(void *c, const unsigned char *b, size_t n) { sink_t *s = c; memcpy(s->slave + s->slave_n, b, n); s->slave_n += n; s->slave[s->slave_n] = 0; }
static void s_echo(void *c, const unsigned char *b, size_t n) { sink_t *s = c; memcpy(s->echo + s->echo_n, b, n); s->echo_n += n; s->echo[s->echo_n] = 0; }
static void s_sig(void *c, int sig) { sink_t *s = c; s->sigs[s->sig_n++] = sig; }
static void s_eof(void *c) { ((sink_t *)c)->eofs++; }

static struct termios nyxian_termios(void)
{
    /* the same settings as NXWindowSessionTerminal.m */
    struct termios t;
    memset(&t, 0, sizeof(t));
    t.c_iflag = ICRNL | INPCK | IUTF8;
    t.c_oflag = OPOST | ONLCR;
    t.c_lflag = ICANON | ECHO | ECHOE | ECHOK | ECHOKE | ECHOCTL | ISIG | IEXTEN;
    for(int i = 0; i < NCCS; i++) t.c_cc[i] = _POSIX_VDISABLE;
    t.c_cc[VINTR] = 0x03; t.c_cc[VQUIT] = 0x1c; t.c_cc[VERASE] = 0x7f; t.c_cc[VKILL] = 0x15;
    t.c_cc[VEOF] = 0x04; t.c_cc[VSUSP] = 0x1a; t.c_cc[VWERASE] = 0x17; t.c_cc[VREPRINT] = 0x12;
    t.c_cc[VLNEXT] = 0x16; t.c_cc[VMIN] = 1; t.c_cc[VTIME] = 0;
    return t;
}

static unsigned char line[64];
static size_t llen;
static int lnext;
static sink_t sink;
static int failures, count;

static void reset(void) { llen = 0; lnext = 0; memset(&sink, 0, sizeof(sink)); }

static void feed(const struct termios *t, const char *bytes)
{
    fork_ldisc_ops_t ops = { s_slave, s_echo, s_sig, s_eof, &sink };
    fork_ldisc_state_t st = { line, sizeof(line), &llen, &lnext };
    fork_ldisc_input(t, &st, &ops, (const unsigned char *)bytes, strlen(bytes));
}

static void show(const char *s)
{
    for(; *s; s++)
    {
        unsigned char c = (unsigned char)*s;
        if(c < 0x20 || c == 0x7f) printf("\\x%02x", c); else putchar(c);
    }
}

static void expect(const char *name, const char *slave, const char *echo, int sigs, int eofs)
{
    count++;
    int ok = strcmp(sink.slave, slave) == 0 && (echo == NULL || strcmp(sink.echo, echo) == 0) && sink.sig_n == sigs && sink.eofs == eofs;
    if(!ok)
    {
        failures++;
        printf("FAIL %s\n  program got: \"", name); show(sink.slave);
        printf("\" (expected \""); show(slave); printf("\")\n  screen got:  \""); show(sink.echo);
        if(echo) { printf("\" (expected \""); show(echo); printf("\")"); } else printf("\"");
        printf("\n  signals %d (expected %d), eof %d (expected %d)\n", sink.sig_n, sigs, sink.eofs, eofs);
    }
    else
    {
        printf("ok   %s\n", name);
    }
}

int main(void)
{
    struct termios t = nyxian_termios();

    reset(); feed(&t, "hola");
    expect("nothing reaches the program before Enter", "", "hola", 0, 0);
    feed(&t, "\r");
    expect("Enter (CR) hands over the line as LF, echo CR LF", "hola\n", "hola\r\n", 0, 0);

    reset(); feed(&t, "abc\x7f\x7f" "d\r");
    expect("Backspace erases on screen and in the line", "ad\n", "abc\b \b\b \bd\r\n", 0, 0);

    reset(); feed(&t, "x\x08y\r");
    expect("^H erases too", "y\n", NULL, 0, 0);

    reset(); feed(&t, "\x7f\x7f" "a\r");
    expect("Backspace on an empty line does nothing", "a\n", "a\r\n", 0, 0);

    reset(); feed(&t, "a\xc3\xb1\x7f\r");
    expect("Backspace erases a whole UTF-8 character (ñ)", "a\n", "a\xc3\xb1\b \b\r\n", 0, 0);

    reset(); feed(&t, "a\xe2\x82\xac\x7f" "b\r");
    expect("Backspace erases a 3-byte character (€)", "ab\n", NULL, 0, 0);

    reset(); feed(&t, "uno dos  \x17tres\r");
    expect("^W erases the last word and the spaces after it", "uno tres\n", NULL, 0, 0);

    reset(); feed(&t, "borrar todo\x15ok\r");
    expect("^U erases the whole line (no signal in ICANON)", "ok\n", NULL, 0, 0);

    reset(); feed(&t, "abc\x03");
    expect("^C: SIGINT, the line is dropped, ^C shown", "", "abc^C", 1, 0);
    if(sink.sig_n == 1 && sink.sigs[0] != SIGINT) { failures++; printf("FAIL ^C is not SIGINT\n"); }
    feed(&t, "z\r");
    expect("after ^C the next line starts empty", "z\n", NULL, 1, 0);

    reset(); feed(&t, "\x1a");
    expect("^Z: SIGTSTP", "", "^Z", 1, 0);
    if(sink.sigs[0] != SIGTSTP) { failures++; printf("FAIL ^Z is not SIGTSTP\n"); }

    reset(); feed(&t, "\x1c");
    expect("^\\: SIGQUIT", "", NULL, 1, 0);

    reset(); feed(&t, "parte\x04");
    expect("^D with text hands it over without Enter", "parte", "parte", 0, 0);
    feed(&t, "\x04");
    expect("^D on an empty line is the end of input", "parte", NULL, 0, 1);

    reset(); feed(&t, "\x16\x03\r");
    expect("^V then ^C: a literal ^C, no signal", "\x03\n", NULL, 0, 0);

    reset(); feed(&t, "\x16\x7f\r");
    expect("^V then Backspace: a literal DEL", "\x7f\n", NULL, 0, 0);

    reset(); feed(&t, "a\tb\r");
    expect("Tab is kept and echoed as is", "a\tb\n", "a\tb\r\n", 0, 0);

    reset(); feed(&t, "x\x01\x7f\r");
    expect("a control key shows as ^A and is erased with two cells", "x\n", "x^A\b \b\b \b\r\n", 0, 0);

    reset(); feed(&t, "ver\x12");
    expect("^R shows the line again", "", "ver^R\r\nver", 0, 0);

    reset(); feed(&t, "uno\rdos\r");
    expect("two lines in one read", "uno\ndos\n", NULL, 0, 0);

    reset();
    for(int i = 0; i < 80; i++) feed(&t, "a");
    feed(&t, "\r");
    count++;
    if(sink.slave_n != 64 || sink.slave[62] != 'a' || sink.slave[63] != '\n') { failures++; printf("FAIL a full line keeps room for Enter (got %zu bytes)\n", sink.slave_n); }
    else printf("ok   a full line keeps room for Enter\n");

    /* raw mode, the way Nyxian's Python line editor reads */
    struct termios raw = t;
    raw.c_lflag &= ~(ICANON | ECHO | IEXTEN);
    reset(); feed(&raw, "ab\x7f\r");
    expect("raw: every byte at once, no echo, CR becomes LF", "ab\x7f\n", "", 0, 0);
    reset(); feed(&raw, "\x15");
    expect("raw: ^U still kills (as before)", "", "", 1, 0);
    if(sink.sigs[0] != SIGKILL) { failures++; printf("FAIL raw ^U is not SIGKILL\n"); }
    reset(); feed(&raw, "\x04");
    expect("raw: ^D is just a byte", "\x04", "", 0, 0);
    reset(); feed(&raw, "\x03");
    expect("raw with ISIG: ^C is SIGINT, not echoed", "", "", 1, 0);

    /* the old settings: no ICANON, no ECHO */
    struct termios old = t;
    old.c_lflag = ISIG;
    reset(); feed(&old, "hola\r");
    expect("old settings behave as before", "hola\n", "", 0, 0);

    /* without ECHO (a password prompt) */
    struct termios secret = t;
    secret.c_lflag &= ~ECHO;
    reset(); feed(&secret, "clave\x7f" "e\r");
    expect("no ECHO: edited but not shown", "clave\n", "", 0, 0);
    secret.c_lflag |= ECHONL;
    reset(); feed(&secret, "x\r");
    expect("ECHONL shows only Enter", "x\n", "\r\n", 0, 0);

    /* ISTRIP */
    struct termios strip = t;
    strip.c_iflag |= ISTRIP;
    reset(); feed(&strip, "\xc1\r");
    expect("ISTRIP clears the 8th bit", "A\n", NULL, 0, 0);

    printf("\n%d of %d tests passed\n", count - failures, count);
    return failures ? 1 : 0;
}
