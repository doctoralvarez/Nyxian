#!/bin/bash
# Fork doctoralvarez/Nyxian — version 0.1.0
# Changelog:
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
LDFLAGS = $RPATH
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
EOF

# ---------- dependencies, for the Mac ----------
HOSTLIB="$T/lib-mac"; IOSLIB="$T/lib-ios"; SRC="$T/src"
mkdir -p "$HOSTLIB" "$IOSLIB" "$SRC"
PKGS_R=$(printf '"%s",' "$@"); PKGS_R="c(${PKGS_R%,})"
log "for the Mac: $* and their dependencies"
"$HOST/bin/Rscript" --vanilla -e "
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
  if (!all(ok)) stop('did not install for the Mac: ', paste(deps[!ok], collapse = ', '))
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
failed=""; built=""
while read -r pkg; do
  [ -n "$pkg" ] || continue
  if [ "${REBUILD:-false}" != "true" ] && published "$pkg"; then
    # the closure's packages already built: fetched, so later ones find their headers (LinkingTo)
    gh release download "$RELEASE" -R "$REPO" -p "$pkg-ios-arm64.tar.gz" -D "$T" --clobber && tar -xzf "$T/$pkg-ios-arm64.tar.gz" -C "$IOSLIB"
    log "$pkg: already built for iOS"
    continue
  fi
  tarball=$(ls "$SRC"/"${pkg}"_*.tar.gz | head -1)
  log "$pkg: building for iOS"
  # R for the Mac runs the install (dependencies load from the Mac library); compiling uses the iOS toolchain
  if R_LIBS="$HOSTLIB" R_LIBS_USER="$HOSTLIB" R_MAKEVARS_USER="$MV" R_MAKEVARS_SITE=/dev/null \
     "$HOST/bin/R" CMD INSTALL --no-test-load --library="$IOSLIB" "$tarball" > "$T/$pkg.log" 2>&1; then
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
if [ -n "$failed" ]; then echo "FAILED for iOS:$failed"; exit 1; fi
