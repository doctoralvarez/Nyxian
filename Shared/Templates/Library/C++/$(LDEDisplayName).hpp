#pragma once
#include <string>

/* A C++ dynamic library: built as lib$(LDEDisplayName).dylib */

namespace library {
    int add(int a, int b);
    std::string greeting(const std::string &name);
}

/* plain C names, for dlsym or other languages */
extern "C" int library_add(int a, int b);
