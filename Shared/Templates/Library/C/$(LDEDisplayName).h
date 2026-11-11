#ifndef LIBRARY_H
#define LIBRARY_H

/* A C dynamic library: built as lib$(LDEDisplayName).dylib */

int library_add(int a, int b);
const char *library_version(void);

#endif
