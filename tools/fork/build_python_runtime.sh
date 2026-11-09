#!/bin/bash
# Fork doctoralvarez/Nyxian — version 1.3.0
# Changelog:
#  - 1.3.0 (2026-11-08): the runtime comes with numpy, scipy, pandas,
#    matplotlib and scikit-learn (and their dependencies) installed, from the
#    fork's ios-wheels release / BeeWare / Flet; everything is compiled to
#    bytecode here (unchecked-hash .pyc, CPython 3.14), so the device does
#    not compile the standard library or the packages on first import.
#  - 1.2.0 (2026-11-08): jedi and parso (pure Python) in lib/nyxian, for the
#    editor's Python completion; not in site-packages, so pip leaves them be.
#  - 1.1.0 (2026-11-08): binary packages from pip (numpy, matplotlib…) link
#    against @rpath/Python.framework/Python, as on every iOS app: libpython
#    now has that install name and an rpath to Frameworks/ next to it, where
#    Nyxian links Python.framework/Python to it.
#  - 1.0.2 (2026-11-07): the 3.14 stdlib lives in Python.xcframework/lib, shared
#    by the slices; 1.0.1 missed it and packed the whole checkout (309 MB).
#    The zip size is now checked.
#  - 1.0.1 (2026-11-07): finds the stdlib, lib-dynload and libpython in the
#    support package instead of assuming paths (the 3.14 layout differs).
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

echo ">>> Layout of the support package"
find "$WORK" -maxdepth 5 -type d -not -path "*/site-packages/*" | sed "s#$WORK/##" | grep -v "^Python.xcframework/ios-arm64_x86_64-simulator/lib/python" | head -80

# the device slice (not the simulator one)
SLICE="$(find "$WORK" -type d -name "ios-arm64" -path "*Python.xcframework*" | head -1)"
[ -n "$SLICE" ] || { echo "no ios-arm64 slice"; exit 1; }
# pure-Python standard library: shared by the slices in 3.14 (Python.xcframework/lib),
# inside the slice in older layouts; never the testbed's copy
STD_SRC=""
for candidate in "$WORK/Python.xcframework/lib/python${PY_VER}" "$SLICE/lib/python${PY_VER}"; do
  if [ -f "$candidate/os.py" ]; then STD_SRC="$candidate"; break; fi
done
# binary modules
DYNLOAD_SRC="$(find "$SLICE" -type d -name lib-dynload | head -1)"
# libpython
LIBPY_SRC="$(find "$SLICE" -path "*Python.framework/Python" -type f | head -1)"
echo "slice=$SLICE"; echo "stdlib=$STD_SRC"; echo "dynload=$DYNLOAD_SRC"; echo "libpython=$LIBPY_SRC"
[ -n "$STD_SRC" ] && [ -f "$STD_SRC/os.py" ] && [ -d "$DYNLOAD_SRC" ] && [ -f "$LIBPY_SRC" ] || { echo "support package layout not understood"; exit 1; }

HOME_DIR="$WORK/python"
STDLIB="$HOME_DIR/lib/python${PY_VER}"
mkdir -p "$HOME_DIR/lib" "$HOME_DIR/bin"

echo ">>> Standard library"
cp -R "$STD_SRC" "$STDLIB"
# architecture-specific parts: lib-dynload and the sysconfig data next to it
cp -R "$(dirname "$DYNLOAD_SRC")/." "$STDLIB/"
# not useful on the device, and large
rm -rf "$STDLIB/test" "$STDLIB/idlelib" "$STDLIB/tkinter" "$STDLIB/turtledemo" "$STDLIB/lib2to3/tests"
find "$HOME_DIR" -name "__pycache__" -prune -exec rm -rf {} +
find "$HOME_DIR" -name "*.xcprivacy" -delete

echo ">>> libpython"
cp "$LIBPY_SRC" "$HOME_DIR/libpython${PY_VER}.dylib"
# wheels for iOS (PyPI, BeeWare, our ios-wheels release) load
# @rpath/Python.framework/Python: same install name, and an rpath to
# $PYTHONHOME/Frameworks, where Nyxian puts Python.framework/Python -> libpython
install_name_tool -id "@rpath/Python.framework/Python" "$HOME_DIR/libpython${PY_VER}.dylib"
install_name_tool -add_rpath "@loader_path/Frameworks" "$HOME_DIR/libpython${PY_VER}.dylib"
otool -l "$HOME_DIR/libpython${PY_VER}.dylib" | grep -A2 -E "LC_ID_DYLIB|LC_RPATH" | grep -E "name|path"

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

echo ">>> jedi + parso (editor completion)"
mkdir -p "$WORK/jedi" "$HOME_DIR/lib/nyxian"
python3 -m pip download --quiet --no-deps --only-binary :all: -d "$WORK/jedi" jedi parso
for wheel in "$WORK"/jedi/*.whl; do
  echo "  $(basename "$wheel")"
  unzip -q -o "$wheel" -d "$HOME_DIR/lib/nyxian"
done
du -sh "$HOME_DIR/lib/nyxian"

echo ">>> bundled packages (installed from the start)"
SITE="$STDLIB/site-packages"
mkdir -p "$WORK/wheels" "$SITE"
python3 -m pip download --quiet --only-binary :all: -d "$WORK/wheels" \
  --platform ios_13_0_arm64_iphoneos --python-version "${PY_VER}" --implementation cp --abi "cp${PY_VER/./}" \
  --find-links https://github.com/doctoralvarez/Nyxian/releases/expanded_assets/ios-wheels \
  --extra-index-url https://pypi.anaconda.org/beeware/simple \
  --extra-index-url https://pypi.flet.dev \
  numpy scipy pandas matplotlib scikit-learn
for wheel in "$WORK"/wheels/*.whl; do
  echo "  $(basename "$wheel")"
  unzip -q -o "$wheel" -d "$SITE"
done
# what pip would do on install: no .data folders left, and an INSTALLER file
for data in "$SITE"/*.data; do
  [ -d "$data" ] || continue
  [ -d "$data/purelib" ] && cp -R "$data/purelib/." "$SITE/"
  [ -d "$data/platlib" ] && cp -R "$data/platlib/." "$SITE/"
  rm -rf "$data"
done
for info in "$SITE"/*.dist-info; do echo "pip" > "$info/INSTALLER"; done
# Nyxian's own list of what came bundled (re-added to a kept site-packages once)
ls "$SITE" > "$HOME_DIR/BUNDLED_PACKAGES"
du -sh "$SITE"

echo ">>> bytecode (CPython $(python3 -c 'import sys; print(sys.version.split()[0])') here)"
HOST_TAG="$(python3 -c 'import sys; print("%d.%d" % sys.version_info[:2])')"
if [ "$HOST_TAG" = "$PY_VER" ]; then
  python3 -m compileall -q -j 0 --invalidation-mode unchecked-hash "$HOME_DIR/lib" >/dev/null 2>&1 || true
  echo "  $(find "$HOME_DIR/lib" -name "*.pyc" | wc -l) .pyc files"
else
  echo "  host Python is $HOST_TAG, not $PY_VER: no bytecode shipped"
fi

echo "${PY_VER}-${PY_BUILD}" > "$HOME_DIR/VERSION"
cp "$WORK/VERSIONS" "$HOME_DIR/VERSIONS" 2>/dev/null || true

mkdir -p "$ROOT/Shared"
rm -f "$OUT"
(cd "$WORK" && zip -qry "$OUT" python)
ls -la "$OUT"
# a runtime is tens of MB; anything far bigger means the wrong folder was packed
SIZE=$(stat -f%z "$OUT")
[ "$SIZE" -lt 450000000 ] || { echo "python-ios.zip is $SIZE bytes: refusing (wrong folder packed?)"; rm -f "$OUT"; exit 1; }
