#!/usr/bin/env python3
# Fork doctoralvarez/Nyxian — version 1.0.0
# Changelog:
#  - 1.0.0 (2026-11-08): meson builds (pandas…) ask the build environment's
#    Python for numpy.get_include(); there numpy is the iOS one, which cannot
#    be imported on the Mac. This finds the folder without importing numpy.
"""Rewrites `run_command(py, ['-c', '...numpy...get_include()...'])` in meson.build files."""
import pathlib
import re
import sys

FIND = (
    "import importlib.util, os; "
    "spec = importlib.util.find_spec('numpy'); "
    "base = os.path.dirname(spec.origin); "
    "core = os.path.join(base, '_core', 'include'); "
    "print(os.path.relpath(core if os.path.isdir(core) else os.path.join(base, 'core', 'include')))"
)
CALL = re.compile(r"run_command\(\s*(\w+)\s*,\s*\[\s*'-c'\s*,\s*('''.*?'''|'(?:[^'\\]|\\.)*')", re.S)


def main(root):
    changed = 0
    for path in pathlib.Path(root).rglob("meson.build"):
        text = path.read_text()

        def replace(match):
            nonlocal changed
            if "get_include" not in match.group(2):
                return match.group(0)
            changed += 1
            return "run_command(%s, ['-c', '''%s'''" % (match.group(1), FIND)

        new = CALL.sub(replace, text)
        if new != text:
            path.write_text(new)
            print("patched", path)
    print("numpy include lookups patched:", changed)


if __name__ == "__main__":
    main(sys.argv[1])
