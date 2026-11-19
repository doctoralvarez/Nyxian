#!/bin/bash
# Fork doctoralvarez/Nyxian — version 1.0.0
# Changelog:
#  - 1.0.0 (2026-11-19): builds C and C++ libraries for iOS (arm64 device,
#    iOS 13.0, static .a + headers + pkg-config files) with CMake or
#    autotools, from a recipe (leptonica, tesseract) or any source archive
#    URL / git repository. Each library is published on the "ios-native"
#    release as ios-native-<name>-<version>.tar.gz and reused from there;
#    Python packages that need one (tesserocr) get them before cibuildwheel.
#
# Usage:
#   native.sh deps <python-package>     native libraries a Python package needs
#   native.sh ensure <spec>...          download from the release or build (+ deps)
#   native.sh env                       CIBW environment for the ensured libraries
#
# <spec>: a recipe name (leptonica, tesseract), name@version, a source archive
# URL (.tar.gz/.tar.xz/.zip) or a git URL (ending in .git, optionally #tag).
#
# Everything lives under one fixed path, so the CMake and pkg-config files
# that record absolute paths work on any Mac (GitHub's or yours).
set -euo pipefail

ROOT=/tmp/nyxian-ios-native
WORK="${RUNNER_TEMP:-/tmp}/ios-native-work"
DIST="${IOS_NATIVE_DIST:-$PWD/native-dist}"
RELEASE=ios-native
REPO="${GITHUB_REPOSITORY:-doctoralvarez/Nyxian}"
MIN_IOS=13.0
mkdir -p "$ROOT" "$WORK" "$DIST"

log() { echo "[native] $*" >&2; }

# ---------- recipes ----------
recipe_version() {
  case "$1" in
    leptonica) echo 1.87.0 ;;
    tesseract) echo 5.5.4 ;;
    *) echo "" ;;
  esac
}
recipe_url() {  # name version
  case "$1" in
    leptonica) echo "https://github.com/DanBloomberg/leptonica/archive/refs/tags/$2.tar.gz" ;;
    tesseract) echo "https://github.com/tesseract-ocr/tesseract/archive/refs/tags/$2.tar.gz" ;;
  esac
}
recipe_deps() {
  case "$1" in
    tesseract) echo leptonica ;;
    *) echo "" ;;
  esac
}
# extra CMake options per library (images: only zlib, from the iOS SDK; BMP and
# PNM are built in, enough for Pillow images handed over by tesserocr)
recipe_cmake_args() {
  case "$1" in
    leptonica) echo "-DENABLE_ZLIB=ON -DENABLE_PNG=OFF -DENABLE_GIF=OFF -DENABLE_JPEG=OFF -DENABLE_TIFF=OFF -DENABLE_WEBP=OFF -DENABLE_OPENJPEG=OFF -DBUILD_PROG=OFF -DSW_BUILD=OFF" ;;
    tesseract) echo "-DBUILD_TRAINING_TOOLS=OFF -DBUILD_TESTS=OFF -DGRAPHICS_DISABLED=ON -DOPENMP_BUILD=OFF -DENABLE_LTO=OFF -DENABLE_NATIVE=OFF -DDISABLE_TIFF=ON -DDISABLE_ARCHIVE=ON -DDISABLE_CURL=ON -DENABLE_CCACHE=OFF -DENABLE_PRECOMPILED_HEADERS=OFF -DINSTALL_CONFIGS=ON -DLEPT_TIFF_RESULT=1 -DLEPT_TIFF_RESULT__TRYRUN_OUTPUT= -DLeptonica_DIR=$ROOT/leptonica/lib/cmake/leptonica" ;;
    *) echo "" ;;
  esac
}
# Python package -> native libraries it links
python_deps() {
  case "$(echo "$1" | tr 'A-Z_' 'a-z-')" in
    tesserocr) echo "leptonica tesseract" ;;
    *) echo "" ;;
  esac
}

# ---------- spec parsing ----------
spec_name() {
  local s="$1"
  case "$s" in
    *github.com/*/*/archive/*|*github.com/*/*/releases/download/*)
      echo "$s" | sed -E 's|.*github\.com/[^/]+/([^/]+)/.*|\1|' | tr 'A-Z' 'a-z' ;;
    http*://*|git@*)
      local b="${s%%#*}"; b="${b%/}"; b="${b##*/}"
      b="${b%.git}"; b="${b%.tar.gz}"; b="${b%.tgz}"; b="${b%.tar.xz}"; b="${b%.tar.bz2}"; b="${b%.zip}"
      # name-1.2.3 -> name
      echo "$b" | sed -E 's/[-_]v?[0-9][0-9A-Za-z.]*$//' | tr 'A-Z' 'a-z' ;;
    *) echo "${s%%@*}" | tr 'A-Z' 'a-z' ;;
  esac
}
spec_version() {
  local s="$1" name
  case "$s" in
    *.git\#*) echo "${s##*#}" ;;
    *.git) echo "head" ;;
    http*://*)
      local b="${s%/}"; b="${b##*/}"
      local v; v=$(echo "$b" | sed -nE 's/.*[-_]v?([0-9][0-9A-Za-z.]*)\.(tar\.gz|tgz|tar\.xz|tar\.bz2|zip)$/\1/p')
      [ -z "$v" ] && v=$(echo "$b" | sed -nE 's/^v?([0-9][0-9A-Za-z.]*)\.(tar\.gz|tgz|tar\.xz|tar\.bz2|zip)$/\1/p')
      echo "${v:-src}" ;;
    *@*) echo "${s#*@}" ;;
    *) name=$(spec_name "$s"); recipe_version "$name" ;;
  esac
}
spec_url() {
  local s="$1" name ver
  case "$s" in
    http*://*|git@*) echo "$s" ;;
    *) name=$(spec_name "$s"); ver=$(spec_version "$s"); recipe_url "$name" "$ver" ;;
  esac
}

# ---------- toolchain ----------
SDK=$(xcrun --sdk iphoneos --show-sdk-path)
CC_BIN=$(xcrun --sdk iphoneos -f clang)
CXX_BIN=$(xcrun --sdk iphoneos -f clang++)
IOS_FLAGS="-arch arm64 -isysroot $SDK -mios-version-min=$MIN_IOS -fPIC"
JOBS=$(sysctl -n hw.ncpu 2>/dev/null || echo 4)

fetch_source() {  # url dest
  local url="$1" dest="$2"
  rm -rf "$dest"; mkdir -p "$dest"
  case "$url" in
    *.git|*.git\#*|git@*)
      local repo="${url%%#*}" ref=""
      [[ "$url" == *#* ]] && ref="${url##*#}"
      if [ -n "$ref" ]; then git clone -q --depth 1 --branch "$ref" "$repo" "$dest/src"
      else git clone -q --depth 1 "$repo" "$dest/src"; fi
      git -C "$dest/src" submodule update -q --init --depth 1 --recursive || true
      echo "$dest/src" ;;
    *)
      local f="$dest/archive"
      curl -fsSL --retry 3 -o "$f" "$url"
      mkdir -p "$dest/x"
      case "$url" in
        *.zip) unzip -q "$f" -d "$dest/x" ;;
        *) tar -xf "$f" -C "$dest/x" ;;
      esac
      local top; top=$(find "$dest/x" -mindepth 1 -maxdepth 1)
      if [ "$(echo "$top" | wc -l)" -eq 1 ] && [ -d "$top" ]; then echo "$top"; else echo "$dest/x"; fi ;;
  esac
}

prefix_paths() {  # ';'-joined prefixes of every library built so far (for CMake)
  local p="" d
  for d in "$ROOT"/*/; do [ -d "$d" ] && p="${p:+$p;}${d%/}"; done
  echo "$p"
}
pc_paths() {
  local p="" d
  for d in "$ROOT"/*/lib/pkgconfig; do [ -d "$d" ] && p="${p:+$p:}$d"; done
  echo "$p"
}

build_cmake() {  # src prefix extra-args
  local src="$1" prefix="$2" extra="$3" bdir="$WORK/build-$(basename "$prefix")"
  rm -rf "$bdir"
  # shellcheck disable=SC2086
  PKG_CONFIG_LIBDIR="$(pc_paths)" PKG_CONFIG_PATH="" \
  cmake -S "$src" -B "$bdir" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_SYSTEM_PROCESSOR=arm64 \
    -DCMAKE_OSX_SYSROOT=iphoneos \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=$MIN_IOS \
    -DCMAKE_C_COMPILER="$CC_BIN" -DCMAKE_CXX_COMPILER="$CXX_BIN" \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    -DCMAKE_INSTALL_PREFIX="$prefix" \
    -DCMAKE_INSTALL_LIBDIR=lib \
    -DCMAKE_PREFIX_PATH="$(prefix_paths)" \
    -DCMAKE_FIND_ROOT_PATH="$SDK;$ROOT" \
    -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
    -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
    -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
    -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY \
    -DCMAKE_FIND_FRAMEWORK=LAST \
    -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_MACOSX_BUNDLE=OFF \
    -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED=NO \
    $extra
  cmake --build "$bdir" -j "$JOBS"
  cmake --install "$bdir"
}

build_autotools() {  # src prefix
  local src="$1" prefix="$2"
  ( cd "$src"
    [ -x configure ] || { [ -x autogen.sh ] && ./autogen.sh; } || autoreconf -fi
    CC="$CC_BIN $IOS_FLAGS" CXX="$CXX_BIN $IOS_FLAGS" \
    CFLAGS="-O2" CXXFLAGS="-O2" \
    PKG_CONFIG_LIBDIR="$(pc_paths)" PKG_CONFIG_PATH="" \
    ./configure --host=aarch64-apple-darwin --prefix="$prefix" --enable-static --disable-shared
    make -j "$JOBS"
    make install )
}

build_meson() {  # src prefix
  local src="$1" prefix="$2" cross="$WORK/ios-cross.ini"
  cat > "$cross" <<EOF
[binaries]
c = ['$CC_BIN', '-arch', 'arm64', '-isysroot', '$SDK', '-mios-version-min=$MIN_IOS']
cpp = ['$CXX_BIN', '-arch', 'arm64', '-isysroot', '$SDK', '-mios-version-min=$MIN_IOS']
ar = '$(xcrun --sdk iphoneos -f ar)'
strip = '$(xcrun --sdk iphoneos -f strip)'
pkg-config = 'pkg-config'
[host_machine]
system = 'ios'
subsystem = 'ios'
kernel = 'xnu'
cpu_family = 'aarch64'
cpu = 'arm64'
endian = 'little'
EOF
  python -m pip install --quiet meson
  PKG_CONFIG_LIBDIR="$(pc_paths)" PKG_CONFIG_PATH="" \
  meson setup "$WORK/build-meson-$(basename "$prefix")" "$src" --cross-file "$cross" \
    --prefix "$prefix" --libdir lib --default-library static --buildtype release
  meson install -C "$WORK/build-meson-$(basename "$prefix")"
}

# a static library needs its own dependencies on the link line too:
# Libs.private (zlib…) is added to Libs, since pip builds do not pass --static;
# a Requires.private module that is not one of these libraries (zlib from the
# iOS SDK has no .pc file) is replaced by its -l flag, else pkg-config fails
flatten_pc() {
  local prefix="$1" f priv req keep extra m
  for f in "$prefix"/lib/pkgconfig/*.pc; do
    [ -f "$f" ] || continue
    priv=$(sed -n 's/^Libs\.private:[[:space:]]*//p' "$f" | head -1)
    req=$(sed -n 's/^Requires\.private:[[:space:]]*//p' "$f" | head -1 | tr ',' ' ')
    keep="" extra=""
    for m in $req; do
      case "$m" in [\<\>=]*|[0-9]*) continue ;; esac
      if ls "$ROOT"/*/lib/pkgconfig/"$m".pc >/dev/null 2>&1; then keep="$keep $m"
      else case "$m" in zlib) extra="$extra -lz" ;; libpng*) extra="$extra -lpng" ;; *) extra="$extra -l${m#lib}" ;; esac; fi
    done
    /usr/bin/sed -i '' -E "s|^Requires\.private:.*$|Requires.private:$keep|" "$f"
    if [ -n "$priv$extra" ]; then
      /usr/bin/sed -i '' -E "s|^(Libs:.*)$|\1 $priv$extra|" "$f"
    fi
    log "$(basename "$f"): $(grep -E '^(Libs|Requires\.private):' "$f" | tr '\n' ' ')"
  done
}

# zip of a built library on the release, or nothing
release_has() {
  gh release view "$RELEASE" -R "$REPO" --json assets -q '.assets[].name' 2>/dev/null | grep -qx "$1"
}

publish() {  # tarball
  gh release view "$RELEASE" -R "$REPO" >/dev/null 2>&1 || \
    gh release create "$RELEASE" -R "$REPO" --prerelease --title "iOS native libraries" \
      --notes "C and C++ libraries built for iOS (arm64 device, iOS $MIN_IOS): static .a, headers and pkg-config files. Used to build iOS wheels for Nyxian's Python. Paths inside point at $ROOT/<name>." >/dev/null
  gh release upload "$RELEASE" "$1" -R "$REPO" --clobber >/dev/null && log "published $(basename "$1") on the $RELEASE release"
}

DONE=" "
ensure_one() {
  local spec="$1" name ver url tarball prefix src
  name=$(spec_name "$spec"); ver=$(spec_version "$spec"); url=$(spec_url "$spec")
  case "$DONE" in *" $name "*) return 0 ;; esac
  if [ -z "$url" ]; then log "$spec: unknown library (give a recipe name or a source URL)"; return 1; fi
  [ -z "$ver" ] && ver=src
  local dep
  for dep in $(recipe_deps "$name"); do ensure_one "$dep"; done
  prefix="$ROOT/$name"
  tarball="ios-native-$name-$ver.tar.gz"
  if [ "${IOS_NATIVE_REBUILD:-0}" != "1" ] && [ "$ver" != "head" ] && release_has "$tarball"; then
    log "$name $ver: already built, from the $RELEASE release"
    rm -rf "$prefix"; mkdir -p "$ROOT"
    gh release download "$RELEASE" -R "$REPO" -p "$tarball" -D "$WORK" --clobber
    tar -xzf "$WORK/$tarball" -C "$ROOT"
  else
    log "$name $ver: building for iOS from $url"
    src=$(fetch_source "$url" "$WORK/src-$name")
    rm -rf "$prefix"
    if [ -f "$src/CMakeLists.txt" ]; then
      build_cmake "$src" "$prefix" "$(recipe_cmake_args "$name")"
    elif [ -f "$src/meson.build" ]; then
      build_meson "$src" "$prefix"
    elif [ -f "$src/configure" ] || [ -f "$src/configure.ac" ] || [ -f "$src/autogen.sh" ]; then
      build_autotools "$src" "$prefix"
    else
      log "$name: no CMake, Meson or autotools build found"; return 1
    fi
    flatten_pc "$prefix"
    # libraries only: no programs (they cannot run on iOS anyway)
    rm -rf "$prefix/bin"
    echo "$name $ver ios-arm64 iOS>=$MIN_IOS from $url" > "$prefix/NYXIAN-NATIVE.txt"
    tar -czf "$DIST/$tarball" -C "$ROOT" "$name"
    log "$name $ver: built ($(du -sh "$prefix" | cut -f1)): $(cd "$prefix" && ls lib/*.a 2>/dev/null | tr '\n' ' ')"
    if [ -n "${GH_TOKEN:-}" ]; then publish "$DIST/$tarball" || log "could not publish $tarball"; fi
  fi
  DONE="$DONE$name "
}

cmd="${1:-}"; shift || true
case "$cmd" in
  deps) python_deps "$1" ;;
  ensure) for s in "$@"; do ensure_one "$s"; done ;;
  env)
    # what the iOS wheel build needs to find and link them
    inc="" lib=""
    for d in "$ROOT"/*/; do
      [ -d "$d/include" ] && inc="$inc -I${d}include"
      [ -d "$d/lib" ] && lib="$lib -L${d}lib"
    done
    echo "PKG_CONFIG_LIBDIR=$(pc_paths) CPPFLAGS='${inc# }' CFLAGS='${inc# }' CXXFLAGS='${inc# }' LDFLAGS='${lib# } -lz -lc++'" ;;
  *) echo "usage: native.sh deps <pkg> | ensure <spec>... | env" >&2; exit 2 ;;
esac
