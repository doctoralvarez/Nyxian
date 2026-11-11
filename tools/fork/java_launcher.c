/*
 Fork doctoralvarez/Nyxian — version 1.1.0
 Changelog:
  - 1.1.0 (2026-11-10): before loading miniJVM, asks its allocator (mimalloc)
    for smaller reservations (64 MiB, not 1 GiB, which iOS refuses) and not
    to print warnings ("unable to allocate aligned OS memory directly").
  - 1.0.0 (2026-11-10): `java` for Nyxian. A tiny executable that loads
    miniJVM (built as a library, lib/libminijvm.dylib, by absolute path from
    NYXIAN_JAVA_HOME) and runs its main with the command line — the same way
    `node` loads Node.js, which Nyxian starts fine. miniJVM is an
    interpreter (its JIT is off on iOS).
*/

#include <dlfcn.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>

int main(int argc, char *argv[])
{
    const char *home = getenv("NYXIAN_JAVA_HOME");
    if(home == NULL || home[0] == 0)
    {
        fprintf(stderr, "java: NYXIAN_JAVA_HOME is not set (start Java from Nyxian)\n");
        return 1;
    }
    /* mimalloc reads these when it starts (an environment that sets them wins) */
    setenv("MIMALLOC_ARENA_RESERVE", "64MiB", 0);
    setenv("MIMALLOC_SHOW_ERRORS", "0", 0);
    setenv("MIMALLOC_VERBOSE", "0", 0);

    char path[PATH_MAX];
    snprintf(path, sizeof(path), "%s/lib/libminijvm.dylib", home);

    void *jvm = dlopen(path, RTLD_NOW | RTLD_GLOBAL);
    if(jvm == NULL)
    {
        fprintf(stderr, "java: cannot load %s: %s\n", path, dlerror());
        return 1;
    }
    int (*jvmMain)(int, char **) = (int (*)(int, char **))dlsym(jvm, "minijvm_main");
    if(jvmMain == NULL)
    {
        fprintf(stderr, "java: minijvm_main not found: %s\n", dlerror());
        return 1;
    }
    return jvmMain(argc, argv);
}
