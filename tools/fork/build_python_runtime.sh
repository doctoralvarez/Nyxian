#!/bin/bash
# Fork doctoralvarez/Nyxian — version 1.0.0
# Changelog:
#  - 1.0.0 (2026-11-07): packs CPython for iOS (BeeWare Python-Apple-support,
#    the official PEP 730 build) as Shared/python-ios.zip: a PYTHONHOME with
#    the standard library, its binary modules, libpython and the `python3`
#    launcher. Nyxian unpacks and signs it on the device.
set -euo pipefail

PY_VER="${PY_VER:-3.14}"
PY_BUILD="${PY_BUILD:-b14}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$ROOT/Shared/python-ios.zip"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

URL="https://github.com/beeware/Python-Apple-support/releases/download/${PY_VER}-${PY_BUILD}/Python-${PY_VER}-iOS-support.${PY_BUILD}.tar.gz"
echo ">>> Downloading $URL"
curl -fsSL --retry 3 -o "$WORK/support.tar.gz" "$URL"
tar -xzf "$WORK/support.tar.gz" -C "$WORK"

SLICE="$WORK/Python.xcframework/ios-arm64"
HOME_DIR="$WORK/python"
STDLIB="$HOME_DIR/lib/python${PY_VER}"
mkdir -p "$HOME_DIR/lib" "$HOME_DIR/bin"

echo ">>> Standard library"
cp -R "$SLICE/lib/python${PY_VER}" "$HOME_DIR/lib/"
# architecture-specific parts: lib-dynload and the sysconfig data
cp -R "$SLICE/lib-arm64/python${PY_VER}/." "$STDLIB/"
# not useful on the device, and large
rm -rf "$STDLIB/test" "$STDLIB/idlelib" "$STDLIB/tkinter" "$STDLIB/turtledemo" "$STDLIB/lib2to3/tests"
find "$HOME_DIR" -name "__pycache__" -prune -exec rm -rf {} +
find "$HOME_DIR" -name "*.xcprivacy" -delete

echo ">>> libpython"
cp "$SLICE/Python.framework/Python" "$HOME_DIR/libpython${PY_VER}.dylib"
install_name_tool -id "@loader_path/libpython${PY_VER}.dylib" "$HOME_DIR/libpython${PY_VER}.dylib"

# binary modules: point any framework reference at the dylib in PYTHONHOME
find "$STDLIB/lib-dynload" -name "*.so" -print0 | while IFS= read -r -d '' so; do
  otool -L "$so" | awk 'NR>1 {print $1}' | grep "Python.framework/Python" | while read -r dep; do
    install_name_tool -change "$dep" "@loader_path/../../../libpython${PY_VER}.dylib" "$so"
  done
done

echo ">>> python3 launcher"
xcrun -sdk iphoneos clang -arch arm64 -miphoneos-version-min=16.0 -O2 \
  -DNYXIAN_PYTHON_VERSION="\"${PY_VER}\"" \
  -o "$HOME_DIR/bin/python3" "$ROOT/tools/fork/python_launcher.c"

echo "${PY_VER}-${PY_BUILD}" > "$HOME_DIR/VERSION"
cp "$WORK/VERSIONS" "$HOME_DIR/VERSIONS" 2>/dev/null || true

mkdir -p "$ROOT/Shared"
rm -f "$OUT"
(cd "$WORK" && zip -qry "$OUT" python)
ls -la "$OUT"
