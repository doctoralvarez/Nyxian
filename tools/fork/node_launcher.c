/*
 Fork doctoralvarez/Nyxian — version 1.0.0
 Changelog:
  - 1.0.0 (2026-11-10): `node` for Nyxian. A tiny executable that loads
    Node.js for iOS (nodejs-mobile's NodeMobile, by absolute path from
    NYXIAN_NODE_HOME) and runs node_start with the command line, so Nyxian
    runs it as a utility like python3. Node.js on iOS runs without JIT
    (V8 --jitless, nodejs-mobile's standard build).
*/

#include <dlfcn.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, char *argv[])
{
    const char *home = getenv("NYXIAN_NODE_HOME");
    if(home == NULL || home[0] == 0)
    {
        fprintf(stderr, "node: NYXIAN_NODE_HOME is not set (start Node.js from Nyxian)\n");
        return 1;
    }
    char path[PATH_MAX];
    snprintf(path, sizeof(path), "%s/lib/NodeMobile", home);

    void *node = dlopen(path, RTLD_NOW | RTLD_GLOBAL);
    if(node == NULL)
    {
        fprintf(stderr, "node: cannot load %s: %s\n", path, dlerror());
        return 1;
    }
    int (*nodeStart)(int, char **) = (int (*)(int, char **))dlsym(node, "node_start");
    if(nodeStart == NULL)
    {
        fprintf(stderr, "node: node_start not found: %s\n", dlerror());
        return 1;
    }

    /* node (libuv) expects the arguments in one block of memory, as the kernel lays them out */
    size_t total = 0;
    for(int i = 0; i < argc; i++) total += strlen(argv[i]) + 1;
    char *block = malloc(total);
    char **args = malloc(sizeof(char *) * (size_t)(argc + 1));
    if(block == NULL || args == NULL) return 1;
    char *cursor = block;
    for(int i = 0; i < argc; i++)
    {
        size_t length = strlen(argv[i]) + 1;
        memcpy(cursor, argv[i], length);
        args[i] = cursor;
        cursor += length;
    }
    args[argc] = NULL;
    /* argv[0] as node knows itself: process.execPath is this launcher */
    return nodeStart(argc, args);
}
