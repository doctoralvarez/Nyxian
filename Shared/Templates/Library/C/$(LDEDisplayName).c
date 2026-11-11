#include "$(LDEDisplayName).h"

int library_add(int a, int b)
{
    return a + b;
}

const char *library_version(void)
{
    return "1.0";
}
