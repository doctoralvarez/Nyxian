/*
 Fork doctoralvarez/Nyxian — version 0.1.0
 Changelog:
  - 0.1.0 (2026-11-19): included first in every C/C++ file of R for iOS.
    iOS has no system() or popen() (an app runs no shell or other programs):
    R's calls go to R_nyxian_shell, a function the host sets (Nyxian's
    Python, through rpy2), which runs the command in Nyxian Shell in this
    same process. With no host function they fail like a missing shell
    (status 127). Nothing here creates processes or executable memory.
*/
#ifndef NYXIAN_R_IOS_H
#define NYXIAN_R_IOS_H

#if defined(__APPLE__)
#include <TargetConditionals.h>
#endif

#if defined(__APPLE__) && TARGET_OS_IPHONE

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef __cplusplus
extern "C" {
#endif

/* runs `cmd` (with `input` on its standard input, or NULL); puts its output in
   *output (malloc'd, the caller frees it) and returns its exit status */
typedef int (*R_nyxian_shell_fn)(const char *cmd, const char *input, char **output);
/* weak: one variable for all of libR, set by the host after loading it */
__attribute__((weak, visibility("default"))) R_nyxian_shell_fn R_nyxian_shell = 0;

static inline int R_nyxian_run(const char *cmd, const char *input, char **output)
{
    if (output) *output = NULL;
    if (!R_nyxian_shell) { errno = ENOENT; return 127; }
    return R_nyxian_shell(cmd, input, output);
}

/* system(): the output goes to R's stdout, the status as a wait status */
static inline int R_nyxian_system(const char *cmd)
{
    if (cmd == NULL) return R_nyxian_shell != 0; /* "is there a shell?" */
    char *out = NULL;
    int status = R_nyxian_run(cmd, NULL, &out);
    if (out) { fputs(out, stdout); fflush(stdout); free(out); }
    return (status & 0xff) << 8;
}

/* popen()/pclose(): "r" runs the command now and reads its output from a
   temporary file; "w" collects what is written and runs it at pclose() */
typedef struct { FILE *file; char *cmd; int writing; int status; } R_nyxian_pipe;
__attribute__((weak)) R_nyxian_pipe R_nyxian_pipes[32];

static inline FILE *R_nyxian_popen(const char *cmd, const char *mode)
{
    int slot = -1;
    for (int i = 0; i < 32; i++) if (R_nyxian_pipes[i].file == NULL) { slot = i; break; }
    if (slot < 0) { errno = EMFILE; return NULL; }
    FILE *f = tmpfile();
    if (!f) return NULL;
    int writing = mode && mode[0] == 'w';
    int status = 0;
    if (!writing) {
        char *out = NULL;
        status = R_nyxian_run(cmd, NULL, &out);
        if (out) { fputs(out, f); free(out); }
        rewind(f);
    }
    R_nyxian_pipes[slot].file = f;
    R_nyxian_pipes[slot].cmd = writing ? strdup(cmd) : NULL;
    R_nyxian_pipes[slot].writing = writing;
    R_nyxian_pipes[slot].status = status;
    return f;
}

static inline int R_nyxian_pclose(FILE *f)
{
    for (int i = 0; i < 32; i++) {
        if (R_nyxian_pipes[i].file != f) continue;
        int status = R_nyxian_pipes[i].status;
        if (R_nyxian_pipes[i].writing) {
            long size;
            fflush(f);
            size = ftell(f);
            char *input = (char *)malloc(size > 0 ? (size_t)size + 1 : 1);
            if (input) {
                rewind(f);
                size_t got = fread(input, 1, size > 0 ? (size_t)size : 0, f);
                input[got] = 0;
                char *out = NULL;
                status = R_nyxian_run(R_nyxian_pipes[i].cmd, input, &out);
                if (out) { fputs(out, stdout); fflush(stdout); free(out); }
                free(input);
            }
            free(R_nyxian_pipes[i].cmd);
        }
        fclose(f);
        R_nyxian_pipes[i].file = NULL;
        R_nyxian_pipes[i].cmd = NULL;
        return (status & 0xff) << 8;
    }
    errno = ECHILD;
    return -1;
}

#ifdef __cplusplus
}
#endif

#define system(cmd) R_nyxian_system(cmd)
#define popen(cmd, mode) R_nyxian_popen(cmd, mode)
#define pclose(f) R_nyxian_pclose(f)

#endif /* iOS */
#endif /* NYXIAN_R_IOS_H */
