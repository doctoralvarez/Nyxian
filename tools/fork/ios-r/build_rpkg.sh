#!/bin/bash
# Fork doctoralvarez/Nyxian — version 0.4.0
# Changelog:
#  - 0.4.0 (2026-11-19): packages that link C libraries find them built for
#    iOS (native.sh: openssl, curl, libpng, libjpeg, libtiff, libwebp,
#    freetype, harfbuzz, fribidi) through pkg-config, before their configure
#    falls back to Homebrew's Mac libraries (openssl, curl, s2, systemfonts,
#    textshaping, ragg, gdtools); png gets a libpng-config for iOS and jpeg
#    JPEG_CFLAGS/JPEG_LIBS. V8 is said to be left out: its JavaScript engine
#    needs JIT, which iOS does not allow.
#  - 0.3.0 (2026-11-19): the Mac builds link CoreFoundation (R for the Mac
#    was built without it, and timechange/s2 need it: "_CFRelease not
#    found"), the iOS builds too; a package that cannot install for the Mac
#    (a missing system library: units needs udunits2, sf needs GDAL) no
#    longer stops the rest: it and the packages needing it are reported and
#    everything else is built.
#  - 0.2.2 (2026-11-19): fs builds its bundled libuv (USE_BUNDLED_LIBUV=1).
#  - 0.2.1 (2026-11-19): cross-compiling is said through a config.site
#    (CONFIG_SITE: cross_compiling=yes), every autoconf script reads it (the
#    configure check was cut short by pipefail); CMake builds inside packages
#    (fs's libuv, nloptr's NLopt) get an iOS toolchain file
#    (CMAKE_TOOLCHAIN_FILE) instead of building for the Mac.
#  - 0.2.0 (2026-11-19): packages with a configure script: autoconf ones are
#    told they cross-compile (--host/--build: they tried to run iOS test
#    programs: stringi, nloptr); pkg-config sees no Mac libraries (fs linked
#    Homebrew's libuv: now its bundled one); per-package settings (xml2:
#    the iOS SDK's libxml2 instead of downloading a Mac one; stringi: its
#    bundled ICU).
#  - 0.1.1 (2026-11-19): the iOS copy starts from the Mac install and only
#    its compiled code is rebuilt for iOS (--libs-only): Matrix runs its own
#    C code while installing, which the iOS build cannot do on the Mac.
#  - 0.1.0 (2026-11-19): R packages (CRAN) for R for iOS. Each package and
#    its dependencies is installed twice: for the Mac (so R for the Mac can
#    load the dependencies while installing) and for iOS, with R for the Mac
#    running R CMD INSTALL but compiling with the iOS toolchain (a Makevars
#    file: Apple's clang for iOS, Flang for iOS, R for iOS's BLAS/LAPACK,
#    nyxian_ios.h first). The iOS copies are checked to be iOS Mach-O and
#    published on the ios-r-packages release as <name>-ios-arm64.tar.gz.
#
# Usage: build_rpkg.sh <package>...   (CRAN names; REBUILD=true builds again)
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
NATIVE="$HERE/../ios-wheels/native.sh"
REPO="${GITHUB_REPOSITORY:-doctoralvarez/Nyxian}"
RVER="${R_IOS_VERSION:-4.6.2}"
T="${RUNNER_TEMP:-/tmp}/r-pkgs"
HOST=/tmp/nyxian-host-R
ROOT=/tmp/nyxian-ios-native
RELEASE=ios-r-packages
CRAN="https://cloud.r-project.org"
JOBS=$(sysctl -n hw.ncpu)
mkdir -p "$T"
log() { echo "[r-pkgs] $*" >&2; }
[ $# -gt 0 ] || { echo "usage: build_rpkg.sh <package>..." >&2; exit 2; }

# ---------- R for the Mac and R for iOS (from the ios-r release) ----------
if [ ! -x "$HOST/bin/R" ]; then
  gh release download ios-r -R "$REPO" -p "host-R-$RVER-macos-arm64.tar.gz" -D "$T" --clobber
  tar -xzf "$T/host-R-$RVER-macos-arm64.tar.gz" -C /tmp
fi
IOS_RH="$T/R"
if [ ! -d "$IOS_RH/lib" ]; then
  gh release download ios-r -R "$REPO" -p "r-ios-$RVER-arm64.tar.gz" -D "$T" --clobber
  tar -xzf "$T/r-ios-$RVER-arm64.tar.gz" -C "$T"
fi
# the Mac build of packages with Fortran (R for the Mac was built with Homebrew's gfortran)
brew list gcc >/dev/null 2>&1 || brew install gcc

# ---------- the iOS toolchain as a Makevars file ----------
IOS_NATIVE_FORTRAN=1 bash "$NATIVE" ensure flang-rt >/dev/null
FC_WRAP=$(bash "$NATIVE" fc)
# C libraries some packages link, built for iOS (from the ios-native release, or built now)
R_NATIVE="openssl curl libpng libjpeg libtiff libwebp freetype harfbuzz fribidi"
for l in $R_NATIVE; do
  bash "$NATIVE" ensure "$l" >/dev/null || log "$l: did not build for iOS (packages that need it will fail)"
done
PCDIRS=""
for l in $R_NATIVE; do [ -d "$ROOT/$l/lib/pkgconfig" ] && PCDIRS="${PCDIRS:+$PCDIRS:}$ROOT/$l/lib/pkgconfig"; done
log "C libraries for iOS: $(ls "$ROOT" | tr '\n' ' ')"
SDK=$(xcrun --sdk iphoneos --show-sdk-path)
CC_BIN=$(xcrun --sdk iphoneos -f clang)
CXX_BIN=$(xcrun --sdk iphoneos -f clang++)
IOS="-arch arm64 -isysroot $SDK -mios-version-min=13.0"
RT=$(ls "$ROOT"/flang-rt/lib/libflang_rt*.a | tr '\n' ' ')
# on the device: <site-packages>/nyxian_r_library/<pkg>/libs/<pkg>.so, R in <site-packages>/nyxian_r/R
RPATH="-Wl,-rpath,@loader_path/../../../nyxian_r/R/lib"
MV="$T/Makevars-ios"
cat > "$MV" <<EOF
CC = $CC_BIN $IOS
CXX = $CXX_BIN $IOS
CXX11 = $CXX_BIN $IOS
CXX14 = $CXX_BIN $IOS
CXX17 = $CXX_BIN $IOS
CXX20 = $CXX_BIN $IOS
CXX23 = $CXX_BIN $IOS
OBJC = $CC_BIN $IOS
OBJCXX = $CXX_BIN $IOS
FC = $FC_WRAP
F77 = $FC_WRAP
CFLAGS = -O2 -fPIC -include $HERE/nyxian_ios.h
CXXFLAGS = -O2 -fPIC -include $HERE/nyxian_ios.h
CXX11FLAGS = -O2 -fPIC -include $HERE/nyxian_ios.h
CXX14FLAGS = -O2 -fPIC -include $HERE/nyxian_ios.h
CXX17FLAGS = -O2 -fPIC -include $HERE/nyxian_ios.h
CXX20FLAGS = -O2 -fPIC -include $HERE/nyxian_ios.h
CXX23FLAGS = -O2 -fPIC -include $HERE/nyxian_ios.h
OBJCFLAGS = -O2 -fPIC
FFLAGS = -O2 -fPIC
FCFLAGS = -O2 -fPIC
CPPFLAGS =
LDFLAGS = $RPATH -framework CoreFoundation
SHLIB_LD = $CC_BIN $IOS
SHLIB_CXXLD = $CXX_BIN $IOS
SHLIB_CXX11LD = $CXX_BIN $IOS
SHLIB_CXX14LD = $CXX_BIN $IOS
SHLIB_CXX17LD = $CXX_BIN $IOS
SHLIB_CXX20LD = $CXX_BIN $IOS
SHLIB_CXX23LD = $CXX_BIN $IOS
SHLIB_FCLD = $CC_BIN $IOS
BLAS_LIBS = -L$IOS_RH/lib -lRblas
LAPACK_LIBS = -L$IOS_RH/lib -lRlapack
FLIBS = $RT -lc++
LIBINTL =
JPEG_CFLAGS = -I$ROOT/libjpeg/include
JPEG_LIBS = -L$ROOT/libjpeg/lib
EOF

# ---------- dependencies, for the Mac ----------
HOSTLIB="$T/lib-mac"; IOSLIB="$T/lib-ios"; SRC="$T/src"
mkdir -p "$HOSTLIB" "$IOSLIB" "$SRC"
PKGS_R=$(printf '"%s",' "$@"); PKGS_R="c(${PKGS_R%,})"
log "for the Mac: $* and their dependencies"
# packages expect R for the Mac to bring CoreFoundation (the official one links it)
printf 'LDFLAGS += -framework CoreFoundation\n' > "$T/Makevars-mac"
R_MAKEVARS_USER="$T/Makevars-mac" "$HOST/bin/Rscript" --vanilla -e "
  options(repos = c(CRAN = '$CRAN'))
  pkgs <- $PKGS_R
  db <- available.packages()
  miss <- setdiff(pkgs, rownames(db)); if (length(miss)) stop('not on CRAN: ', paste(miss, collapse = ', '))
  deps <- unique(c(pkgs, unlist(tools::package_dependencies(pkgs, db = db, which = c('Depends', 'Imports', 'LinkingTo'), recursive = TRUE))))
  base <- rownames(installed.packages(lib.loc = .Library, priority = 'base'))
  deps <- setdiff(deps, base)
  writeLines(deps, '$T/closure.txt')
  todo <- setdiff(deps, rownames(installed.packages(lib.loc = '$HOSTLIB')))
  if (length(todo)) install.packages(todo, lib = '$HOSTLIB', Ncpus = $JOBS, quiet = TRUE)
  ok <- deps %in% rownames(installed.packages(lib.loc = '$HOSTLIB'))
  # what could not install for the Mac (a system library it needs is missing), and every
  # package that needs one of those: left out, the rest goes on
  bad <- deps[!ok]
  if (length(bad)) {
    rdeps <- tools::package_dependencies(deps, db = db, which = c('Depends', 'Imports', 'LinkingTo'), recursive = TRUE)
    blocked <- deps[vapply(deps, function(p) p %in% bad || any(rdeps[[p]] %in% bad), NA)]
    message('could not install for the Mac: ', paste(bad, collapse = ', '))
    message('left out (they need those): ', paste(setdiff(blocked, bad), collapse = ', '))
    writeLines(blocked, '$T/blocked.txt')
    deps <- setdiff(deps, blocked)
  }
  # install order for iOS: dependencies first
  order <- character()
  visit <- function(p) { if (p %in% order) return(invisible())
    for (d in intersect(tools::package_dependencies(p, db = db, which = c('Depends', 'Imports', 'LinkingTo'))[[1]], deps)) visit(d)
    order <<- c(order, p) }
  for (p in deps) visit(p)
  writeLines(order, '$T/order.txt')
  download.packages(order, destdir = '$SRC', quiet = TRUE)
"
log "closure: $(tr '\n' ' ' < "$T/order.txt")"

# ---------- for iOS ----------
published() { gh release view "$RELEASE" -R "$REPO" --json assets -q '.assets[].name' 2>/dev/null | grep -qx "$1-ios-arm64.tar.gz"; }
gh release view "$RELEASE" -R "$REPO" >/dev/null 2>&1 || gh release create "$RELEASE" -R "$REPO" --prerelease \
  --title "R packages for iOS" --notes "CRAN packages built for R for iOS (Nyxian): <name>-ios-arm64.tar.gz, unpacked into R's library by install.packages() in Nyxian." >/dev/null
# what a package's own configure needs to build for iOS
mkdir -p "$T/pkgconfig-none" "$T/bin"
# png's Makevars asks libpng-config (Homebrew's is the Mac one): this one answers for iOS
cat > "$T/bin/libpng-config" <<EOF
#!/bin/sh
export PKG_CONFIG_LIBDIR="$PCDIRS" PKG_CONFIG_PATH=""
case "\$*" in
  *--cflags*|*--I_opts*) exec pkg-config --cflags libpng ;;
  *) exec pkg-config --static --libs libpng ;;
esac
EOF
chmod +x "$T/bin/libpng-config"
# autoconf scripts read this: no iOS test program can run here
cat > "$T/config.site" <<EOF
cross_compiling=yes
EOF
# CMake builds inside a package (bundled libraries) target iOS
cat > "$T/ios-toolchain.cmake" <<EOF
set(CMAKE_SYSTEM_NAME iOS)
set(CMAKE_SYSTEM_PROCESSOR arm64)
set(CMAKE_OSX_SYSROOT "$SDK")
set(CMAKE_OSX_ARCHITECTURES arm64)
set(CMAKE_OSX_DEPLOYMENT_TARGET 13.0)
set(CMAKE_C_COMPILER "$CC_BIN")
set(CMAKE_CXX_COMPILER "$CXX_BIN")
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
set(CMAKE_FIND_ROOT_PATH "$SDK")
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
EOF
ios_install() {  # pkg tarball
  local pkg="$1" tarball="$2" cargs="" envs=()
  case "$pkg" in
    xml2) envs+=("INCLUDE_DIR=$SDK/usr/include/libxml2" "LIB_DIR=$SDK/usr/lib") ;;
    stringi) cargs="--disable-pkg-config" ;;
    # its configure downloads Homebrew's Mac libuv (autobrew); the bundled one builds for iOS
    fs) envs+=("USE_BUNDLED_LIBUV=1") ;;
  esac
  env ${envs[@]+"${envs[@]}"} PATH="$T/bin:$PATH" PKG_CONFIG_LIBDIR="${PCDIRS:-$T/pkgconfig-none}" PKG_CONFIG_PATH="" \
    CONFIG_SITE="$T/config.site" CMAKE_TOOLCHAIN_FILE="$T/ios-toolchain.cmake" SDKROOT="$SDK" \
    R_LIBS="$HOSTLIB" R_LIBS_USER="$HOSTLIB" R_MAKEVARS_USER="$MV" R_MAKEVARS_SITE=/dev/null \
    "$HOST/bin/R" CMD INSTALL --libs-only --no-test-load --library="$IOSLIB" \
    ${cargs:+--configure-args="$cargs"} "$tarball"
}

failed=""; built=""
while read -r pkg; do
  [ -n "$pkg" ] || continue
  if [ "${REBUILD:-false}" != "true" ] && published "$pkg"; then
    # the closure's packages already built: fetched, so later ones find their headers (LinkingTo)
    gh release download "$RELEASE" -R "$REPO" -p "$pkg-ios-arm64.tar.gz" -D "$T" --clobber && tar -xzf "$T/$pkg-ios-arm64.tar.gz" -C "$IOSLIB"
    log "$pkg: already built for iOS"
    continue
  fi
  if [ "$pkg" = V8 ]; then
    log "V8: left out (Google's V8 JavaScript engine needs JIT, which iOS does not allow)"
    failed="$failed $pkg"; continue
  fi
  tarball=$(ls "$SRC"/"${pkg}"_*.tar.gz | head -1)
  log "$pkg: building for iOS"
  # the Mac install (R code, lazy-load databases, help: the same on any platform; packages
  # like Matrix run their own C code while installing, which only the Mac build can) is
  # copied, and only its compiled code is built again for iOS (--libs-only)
  rm -rf "$IOSLIB/$pkg"; cp -R "$HOSTLIB/$pkg" "$IOSLIB/$pkg"
  ok=0
  if [ ! -d "$IOSLIB/$pkg/libs" ]; then
    ok=1   # R code only
  elif ios_install "$pkg" "$tarball" > "$T/$pkg.log" 2>&1; then
    ok=1
  fi
  if [ "$ok" = 1 ]; then
    bad=""
    for so in "$IOSLIB/$pkg"/libs/*.so; do
      [ -f "$so" ] || continue
      plat=$(xcrun vtool -show-build "$so" 2>/dev/null | awk '/platform/{print $2; exit}')
      [ "$plat" = "IOS" ] || bad="$bad $(basename "$so")($plat)"
    done
    if [ -n "$bad" ]; then
      log "$pkg: not built for iOS:$bad"; failed="$failed $pkg"; continue
    fi
    tar -czf "$T/$pkg-ios-arm64.tar.gz" -C "$IOSLIB" "$pkg"
    gh release upload "$RELEASE" "$T/$pkg-ios-arm64.tar.gz" -R "$REPO" --clobber >/dev/null
    log "$pkg: published ($(du -sh "$IOSLIB/$pkg" | cut -f1))"
    built="$built $pkg"
  else
    log "$pkg: did not build for iOS:"; grep -E "error|Error|ERROR" "$T/$pkg.log" | head -25; tail -15 "$T/$pkg.log"
    failed="$failed $pkg"
  fi
done < "$T/order.txt"

echo "built for iOS:${built:- (none new)}"
if [ -s "$T/blocked.txt" ]; then
  echo "not possible yet (a system library is missing): $(tr '\n' ' ' < "$T/blocked.txt")"
  failed="$failed $(tr '\n' ' ' < "$T/blocked.txt")"
fi
if [ -n "$failed" ]; then echo "FAILED for iOS:$failed"; exit 1; fi
