/*
 Fork doctoralvarez/Nyxian — version 1.0.0
 Changelog:
  - 1.0.0 (2026-11-07): `python3` for Nyxian. A tiny executable that loads
    CPython (libpython3.x.dylib, by absolute path from PYTHONHOME) and runs
    Py_BytesMain. It is not linked against Python, so it needs no @rpath:
    Nyxian runs it as a utility from its own folder.
*/

#include <dlfcn.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifndef NYXIAN_PYTHON_VERSION
#define NYXIAN_PYTHON_VERSION "3.14"
#endif

int main(int argc, char *argv[])
{
    const char *dylib = getenv("NYXIAN_PYTHON_DYLIB");
    char path[PATH_MAX];
    if(dylib == NULL || dylib[0] == 0)
    {
        const char *home = getenv("PYTHONHOME");
        if(home == NULL || home[0] == 0)
        {
            fprintf(stderr, "python3: PYTHONHOME is not set (start Python from Nyxian)\n");
            return 1;
        }
        snprintf(path, sizeof(path), "%s/libpython" NYXIAN_PYTHON_VERSION ".dylib", home);
        dylib = path;
    }
    
    void *python = dlopen(dylib, RTLD_NOW | RTLD_GLOBAL);
    if(python == NULL)
    {
        fprintf(stderr, "python3: cannot load %s: %s\n", dylib, dlerror());
        return 1;
    }
    
    int (*bytesMain)(int, char **) = (int (*)(int, char **))dlsym(python, "Py_BytesMain");
    if(bytesMain == NULL)
    {
        fprintf(stderr, "python3: Py_BytesMain not found: %s\n", dlerror());
        return 1;
    }
    return bytesMain(argc, argv);
}
