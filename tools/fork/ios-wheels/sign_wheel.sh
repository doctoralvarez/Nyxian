#!/bin/bash
# Fork doctoralvarez/Nyxian — version 1.0.0
# Changelog:
#  - 1.0.0 (2026-11-19): gives every binary (.so, .dylib) inside an iOS wheel an
#    ad-hoc code signature (LC_CODE_SIGNATURE), like the binaries Nyxian builds
#    itself (-Wl,-adhoc_codesign): without one, dlopen in Nyxian refuses it
#    ("missing code signature"). The wheel is repacked with a fresh RECORD.
# Usage: sign_wheel.sh <wheel>...
set -euo pipefail
for whl in "$@"; do
  tmp=$(mktemp -d)
  python -m wheel unpack -d "$tmp" "$whl" >/dev/null
  root=$(ls -d "$tmp"/*/ | head -1)
  n=0
  while IFS= read -r -d '' bin; do
    if file "$bin" | grep -q "Mach-O"; then
      codesign --force --sign - "$bin"
      n=$((n + 1))
    fi
  done < <(find "$root" -type f \( -name '*.so' -o -name '*.dylib' \) -print0)
  if [ "$n" -gt 0 ]; then
    out=$(mktemp -d)
    python -m wheel pack -d "$out" "$root" >/dev/null
    mv -f "$out"/*.whl "$whl"
    rm -rf "$out"
    echo "$(basename "$whl"): $n binaries signed (ad-hoc)"
  fi
  rm -rf "$tmp"
done
