#include "$(LDEDisplayName).hpp"

namespace library {
    int add(int a, int b) { return a + b; }
    std::string greeting(const std::string &name) { return "Hello, " + name + "!"; }
}

extern "C" int library_add(int a, int b) { return library::add(a, b); }
