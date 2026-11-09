#!/bin/sh
# Fork doctoralvarez/Nyxian — version 1.0.0
# Changelog:
#  - 1.0.0 (2026-11-09): copies the line discipline out of tty.c and runs its tests.
set -e
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../.." && pwd)
out=${TMPDIR:-/tmp}/nyxian-ldisc-test
mkdir -p "$out"
sed -n '/BEGIN ForkLineDiscipline/,/END ForkLineDiscipline/p' \
  "$root/Nyxian/LindChain/ProcEnvironment/Surface/tty/tty.c" > "$out/ldisc.inc"
test -s "$out/ldisc.inc"
cp "$here/main.c" "$out/main.c"
${CC:-cc} -std=c11 -D_DEFAULT_SOURCE -D_DARWIN_C_SOURCE -Wall -Wextra -Werror -Wno-unused-function -Wno-unused-parameter \
  -o "$out/ldisc_test" "$out/main.c"
"$out/ldisc_test"
