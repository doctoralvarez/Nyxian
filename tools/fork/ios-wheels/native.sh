#!/bin/bash
# Fork doctoralvarez/Nyxian — version 1.1.2
# Changelog:
#  - 1.1.2 (2026-11-19): flang-rt for iOS: EXECUTE_COMMAND_LINE answers "not
#    supported" instead of calling system(), which iOS does not have.
#  - 1.1.1 (2026-11-19): the Fortran wrapper links with Apple's clang for iOS
#    (plus Flang's runtime for iOS when built), so CMake's Fortran checks
#    (FortranCInterface in LAPACK) can link; flang-rt no longer gets
#    -mmacosx-version-min=10.7 next to the iOS target.
#  - 1.1.0 (2026-11-19): Fortran (experimental): LLVM Flang from Homebrew
#    compiles for arm64-apple-ios through a wrapper (drops -arch/-isysroot/
#    -m*-version-min, which flang does not take, and adds --target); CMake,
#    Meson and autotools get it as their Fortran compiler. Recipes: flang-rt
#    (Flang's runtime built for iOS from llvm-project at flang's own version,
#    needed to link Fortran code) and lapack (Reference-LAPACK with BLAS,
#    CBLAS and LAPACKE). IOS_NATIVE_FORTRAN=1 also builds flang-rt first.
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
#   IOS_NATIVE_FORTRAN=1                Fortran library: flang-rt is built too
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
    lapack) echo 3.12.1 ;;
    flang-rt) flang_version ;;
    *) echo "" ;;
  esac
}
recipe_url() {  # name version
  case "$1" in
    leptonica) echo "https://github.com/DanBloomberg/leptonica/archive/refs/tags/$2.tar.gz" ;;
    tesseract) echo "https://github.com/tesseract-ocr/tesseract/archive/refs/tags/$2.tar.gz" ;;
    lapack) echo "https://github.com/Reference-LAPACK/lapack/archive/refs/tags/v$2.tar.gz" ;;
    flang-rt) echo "llvm-project:llvmorg-$2" ;;
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
    lapack) echo "-DCBLAS=ON -DLAPACKE=ON -DBUILD_TESTING=OFF -DBUILD_INDEX64=OFF -DUSE_OPTIMIZED_BLAS=OFF" ;;
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

# ---------- Fortran (LLVM Flang, experimental) ----------
FLANG=""
find_flang() {
  [ -n "$FLANG" ] && return 0
  local f
  for f in flang flang-new; do
    if command -v "$f" >/dev/null 2>&1; then FLANG=$(command -v "$f"); break; fi
  done
  if [ -z "$FLANG" ] && command -v brew >/dev/null; then
    brew install flang >&2 || return 1
    local p; p=$(brew --prefix flang)
    for f in "$p/bin/flang" "$p/bin/flang-new"; do [ -x "$f" ] && FLANG="$f" && break; done
  fi
  [ -n "$FLANG" ] || return 1
  log "Fortran compiler: $FLANG ($("$FLANG" --version 2>&1 | head -1))"
}
flang_version() {
  find_flang || { echo ""; return; }
  "$FLANG" --version 2>&1 | head -1 | sed -nE 's/.*version ([0-9]+\.[0-9]+\.[0-9]+).*/\1/p'
}
# flang does not take Apple's -arch/-isysroot/-m*-version-min: the wrapper drops them and
# gives the iOS target instead, so any build system can use it as its Fortran compiler
FC_WRAP=""
fortran_wrapper() {
  [ -n "$FC_WRAP" ] && return 0
  find_flang || return 1
  FC_WRAP="$WORK/ios-flang"
  {
    echo '#!/bin/bash'
    echo "FLANG='$FLANG'; CC_BIN='$CC_BIN'; SDK='$SDK'; MIN_IOS='$MIN_IOS'; RT='$ROOT/flang-rt/lib'"
    cat <<'EOF'
# compiles with flang for arm64-apple-ios; links with Apple's clang for iOS (flang's own
# link step would use its macOS runtime), adding Flang's runtime built for iOS when present
args=(); skip=0; link=1; sources=()
for a in "$@"; do
  if [ $skip = 1 ]; then skip=0; continue; fi
  case "$a" in
    -arch|-isysroot) skip=1; continue ;;
    -mios-version-min=*|-miphoneos-version-min=*|-mmacosx-version-min=*|-fembed-bitcode*) continue ;;
    -c|-E|-S|-M|-MM|-fsyntax-only|--version|-cpp-only|-emit-llvm) link=0 ;;
  esac
  args+=("$a")
done
if [ $link = 0 ] || [ ${#args[@]} = 0 ] || [ "${args[*]}" = "-v" ]; then
  exec "$FLANG" --target=arm64-apple-ios$MIN_IOS "${args[@]}"
fi
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
fflags=(); linkargs=(); n=0
for a in "${args[@]}"; do
  case "$a" in
    *.f|*.F|*.for|*.FOR|*.f77|*.F77|*.f90|*.F90|*.f95|*.F95|*.f03|*.F03|*.f08|*.F08)
      [ -f "$a" ] && sources+=("$a") || linkargs+=("$a") ;;
    -O*|-g|-f*|-I*|-D*|-J*|-module-dir|-cpp|-nocpp|-ffixed-form|-ffree-form)
      fflags+=("$a"); case "$a" in -f*|-I*|-J*|-module-dir|-cpp|-nocpp) ;; *) linkargs+=("$a") ;; esac ;;
    *) linkargs+=("$a") ;;
  esac
done
for f in "${sources[@]}"; do
  n=$((n + 1))
  "$FLANG" --target=arm64-apple-ios$MIN_IOS "${fflags[@]}" -c "$f" -o "$tmp/f$n.o" || exit 1
  linkargs+=("$tmp/f$n.o")
done
rt=()
if [ -d "$RT" ]; then
  rt+=("-L$RT")
  for lib in "$RT"/libflang_rt*.a; do [ -f "$lib" ] && { l=${lib##*/lib}; rt+=("-l${l%.a}"); }; done
fi
exec "$CC_BIN" -arch arm64 -isysroot "$SDK" -mios-version-min=$MIN_IOS "${linkargs[@]}" "${rt[@]}" -lc++
EOF
  } > "$FC_WRAP"
  chmod +x "$FC_WRAP"
}
has_fortran() {  # src
  [ "${IOS_NATIVE_FORTRAN:-0}" = "1" ] && return 0
  find "$1" -maxdepth 4 -type f \( -iname '*.f' -o -iname '*.f90' -o -iname '*.f95' -o -iname '*.f03' -o -iname '*.f08' -o -iname '*.for' \) 2>/dev/null | head -1 | grep -q .
}

# Flang's runtime for iOS, from llvm-project at the version of the flang that compiles
build_flang_rt() {  # tag prefix
  local tag="$1" prefix="$2" src="$WORK/llvm-project" bdir="$WORK/build-flang-rt"
  fortran_wrapper || return 1
  rm -rf "$src" "$bdir"
  git clone -q --depth 1 --branch "$tag" --filter=blob:none --sparse https://github.com/llvm/llvm-project "$src"
  git -C "$src" sparse-checkout set runtimes flang-rt flang/include flang/lib/Decimal flang/lib/Common \
    flang/module flang/cmake cmake llvm/cmake llvm/utils/llvm-lit llvm/utils/merge-json.py third-party >/dev/null 2>&1 \
    || git -C "$src" sparse-checkout set runtimes flang-rt flang cmake llvm/cmake llvm/utils third-party
  # EXECUTE_COMMAND_LINE calls system(), which iOS does not have (an app runs no shell):
  # on iOS it reports "not supported" (-1, ENOENT) like a system without a shell
  local ex="$src/flang-rt/lib/runtime/execute.cpp"
  if [ -f "$ex" ] && ! grep -q NyxianSystem "$ex"; then
    perl -pi -e 's/std::system\(/NyxianSystem(/g' "$ex"
    perl -0pi -e 's/(#include <limits>\n)/$1#if defined(__APPLE__)\n#include <TargetConditionals.h>\n#endif\nstatic int NyxianSystem(const char *cmd) {\n#if defined(__APPLE__) && TARGET_OS_IPHONE\n  (void)cmd;\n  errno = ENOENT;\n  return -1;\n#else\n  return std::system(cmd);\n#endif\n}\n/' "$ex"
    grep -c NyxianSystem "$ex" | sed 's/^/[native] execute.cpp patched: /' >&2
  fi
  # flang-rt adds -mmacosx-version-min=10.7 for any Apple build: not for iOS
  /usr/bin/sed -i '' -E 's/-mmacosx-version-min=\$\{DARWIN_osx_BUILTIN_MIN_VER\}//' "$src/flang-rt/cmake/modules/AddFlangRT.cmake"
  cmake -S "$src/runtimes" -B "$bdir" -G Ninja \
    -DLLVM_ENABLE_RUNTIMES=flang-rt \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_SYSTEM_PROCESSOR=arm64 \
    -DCMAKE_OSX_SYSROOT=iphoneos \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=$MIN_IOS \
    -DCMAKE_C_COMPILER="$CC_BIN" -DCMAKE_CXX_COMPILER="$CXX_BIN" \
    -DCMAKE_Fortran_COMPILER="$FC_WRAP" -DCMAKE_Fortran_COMPILER_WORKS=ON \
    -DCMAKE_Fortran_COMPILER_ID=LLVMFlang \
    -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY \
    -DCMAKE_INSTALL_PREFIX="$prefix" \
    -DFLANG_RT_INCLUDE_TESTS=OFF -DLLVM_INCLUDE_TESTS=OFF \
    -DFLANG_RT_ENABLE_STATIC=ON -DFLANG_RT_ENABLE_SHARED=OFF \
    -DLLVM_DEFAULT_TARGET_TRIPLE=arm64-apple-ios$MIN_IOS \
    -DFLANG_RT_INSTALL_RESOURCE_PATH=lib
  cmake --build "$bdir" -j "$JOBS"
  cmake --install "$bdir"
  # whatever directory the runtime chose: every .a also in lib/
  find "$prefix" -name '*.a' -not -path "$prefix/lib/*.a" -exec cp -f {} "$prefix/lib/" \; 2>/dev/null || true
  mkdir -p "$prefix/lib/pkgconfig"
  local libs; libs=$(cd "$prefix/lib" && ls libflang_rt*.a 2>/dev/null | sed -E 's/^lib(.*)\.a$/-l\1/' | tr '\n' ' ')
  cat > "$prefix/lib/pkgconfig/flang-rt.pc" <<EOF
prefix=$prefix
libdir=\${prefix}/lib
Name: flang-rt
Description: LLVM Flang Fortran runtime for iOS
Version: ${tag#llvmorg-}
Libs: -L\${libdir} $libs -lc++
EOF
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
      if [ -n "$ref" ]; then git clone -q --depth 1 --branch "$ref" "$repo" "$dest/src" || return 1
      else git clone -q --depth 1 "$repo" "$dest/src" || return 1; fi
      git -C "$dest/src" submodule update -q --init --depth 1 --recursive || true
      echo "$dest/src" ;;
    *)
      local f="$dest/archive"
      curl -fsSL --retry 3 -o "$f" "$url" || return 1
      mkdir -p "$dest/x"
      case "$url" in
        *.zip) unzip -q "$f" -d "$dest/x" || return 1 ;;
        *) tar -xf "$f" -C "$dest/x" || return 1 ;;
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
  FORTRAN_CMAKE=""
  if has_fortran "$src" && fortran_wrapper; then
    # no Fortran program can be linked for iOS before flang-rt exists: the checks only compile
    FORTRAN_CMAKE="-DCMAKE_Fortran_COMPILER=$FC_WRAP -DCMAKE_Fortran_COMPILER_WORKS=ON -DCMAKE_Fortran_COMPILER_ID=LLVMFlang"
  fi
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
    $FORTRAN_CMAKE \
    $extra
  cmake --build "$bdir" -j "$JOBS"
  cmake --install "$bdir"
}

build_autotools() {  # src prefix
  local src="$1" prefix="$2"
  ( cd "$src"
    [ -x configure ] || { [ -x autogen.sh ] && ./autogen.sh; } || autoreconf -fi
    if has_fortran . && fortran_wrapper; then export FC="$FC_WRAP" F77="$FC_WRAP" FFLAGS="-O2" FCFLAGS="-O2"; fi
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
$( has_fortran "$src" && fortran_wrapper && echo "fortran = ['$FC_WRAP']" )
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
  if [ "$url" = "llvm-project:llvmorg-" ]; then log "flang-rt: no Fortran compiler (LLVM Flang) on this Mac"; return 1; fi
  [ -z "$ver" ] && ver=src
  local dep
  for dep in $(recipe_deps "$name"); do ensure_one "$dep"; done
  # Fortran code needs Flang's runtime to be linked later: built (or fetched) too, if it can be
  if [ "${IOS_NATIVE_FORTRAN:-0}" = "1" ] && [ "$name" != "flang-rt" ]; then
    IOS_NATIVE_FORTRAN=0 bash "$0" ensure flang-rt || log "flang-rt (Flang's runtime) did not build for iOS: $name can still build, but linking it needs that runtime"
    case "$DONE" in *" flang-rt "*) ;; *) [ -d "$ROOT/flang-rt" ] && DONE="${DONE}flang-rt " ;; esac
  fi
  prefix="$ROOT/$name"
  tarball="ios-native-$name-$ver.tar.gz"
  if [ "${IOS_NATIVE_REBUILD:-0}" != "1" ] && [ "$ver" != "head" ] && release_has "$tarball"; then
    log "$name $ver: already built, from the $RELEASE release"
    rm -rf "$prefix"; mkdir -p "$ROOT"
    gh release download "$RELEASE" -R "$REPO" -p "$tarball" -D "$WORK" --clobber
    tar -xzf "$WORK/$tarball" -C "$ROOT"
  else
    log "$name $ver: building for iOS from $url"
    rm -rf "$prefix"
    if [ "${url#llvm-project:}" != "$url" ]; then
      build_flang_rt "${url#llvm-project:}" "$prefix"
    elif ! src=$(fetch_source "$url" "$WORK/src-$name"); then
      log "$name: could not download $url"; return 1
    elif [ -f "$src/CMakeLists.txt" ]; then
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
