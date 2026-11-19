#!/usr/bin/env python3
# Fork doctoralvarez/Nyxian — version 1.0.0
# Changelog:
#  - 1.0.0 (2026-11-19): CMake projects that run numpy.f2py (slycot…) do it
#    with the build environment's Python, where numpy is the iOS one and
#    cannot be imported on the Mac. Those commands run with a Mac Python that
#    has the same numpy instead (f2py only writes C and Fortran sources).
"""patch_f2py.py <project> <mac-python>: numpy.f2py commands in CMake files use <mac-python>."""
import pathlib
import re
import sys

PY = re.compile(r'"?\$\{(?:Python3?|PYTHON3?)_EXECUTABLE\}"?')


def main(root, host):
    changed = 0
    files = list(pathlib.Path(root).rglob("CMakeLists.txt")) + list(pathlib.Path(root).rglob("*.cmake"))
    for path in files:
        text = path.read_text(errors="replace")
        lines = text.split("\n")
        for i, line in enumerate(lines):
            # the command line itself, or execute_process/add_custom_command blocks whose code
            # imports numpy.f2py on one of the next few lines
            window = "\n".join(lines[i:i + 4])
            if PY.search(line) and "f2py" in window:
                lines[i] = PY.sub('"%s"' % host, line)
                changed += 1
        new = "\n".join(lines)
        if new != text:
            path.write_text(new)
            print("patched", path)
    print("numpy.f2py commands now on the Mac's Python:", changed)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
