#!/bin/bash
# Fork doctoralvarez/Nyxian — version 0.3.0
# Changelog:
#  - 0.3.0 (2026-11-19): R_HOME for iOS: R code, lazy-load databases, help and
#    data from R for the Mac (same version and options; R for iOS cannot run
#    on the Mac to make them); libR, BLAS/LAPACK, modules and every base
#    package's compiled code built for iOS (all checked to be iOS Mach-O);
#    Rprofile.site with the substitutes; published on the ios-r release.
#  - 0.2.1 (2026-11-19): all of R's C and Fortran compiles for iOS; the build
#    steps that run R use R for the Mac (R_EXE).
#  - 0.2.0 (2026-11-19): configure passes for iOS. Every C/C++ file includes
#    nyxian_ios.h first (system()/popen() go to Nyxian Shell through a hook);
#    make -k lists every file that does not build yet in one run.
#  - 0.1.2 (2026-11-19): BLAS/LAPACK for iOS (the Reference-LAPACK built
#    here) is on the link line: configure's link checks ask for -lblas.
#  - 0.1.1 (2026-11-19): zlib's version check preset for iOS (zlib comes
#    with the SDK); iconv's run-time results come from the Mac too.
#  - 0.1.0 (2026-11-19): first stage of R for iOS. Builds R for the Mac (the
#    same version) and configures R for iOS (arm64 device, iOS 13.0) with it:
#    the results of configure's run-time tests (programs it would run, which
#    cannot run for iOS on a Mac) come from the Mac build, whose C library is
#    the same; R's libraries (xz, pcre2 without JIT, curl + OpenSSL, Flang's
#    runtime) come from native.sh. Then it compiles as much as builds.
#
# Usage: build_r.sh <R version>   (in the repository; writes under $RUNNER_TEMP/r-ios)
set -euo pipefail

RVER="${1:-4.6.2}"
HERE="$(cd "$(dirname "$0")" && pwd)"
NATIVE="$HERE/../ios-wheels/native.sh"
T="${RUNNER_TEMP:-/tmp}/r-ios"
HOST=/tmp/nyxian-host-R      # R for the Mac (fixed path: its scripts keep it; reused from the release)
SRC_HOST="$T/src-host"
SRC_IOS="$T/src-ios"
OUT="$T/out"
ROOT=/tmp/nyxian-ios-native
MIN_IOS=13.0
JOBS=$(sysctl -n hw.ncpu)
mkdir -p "$T" "$OUT"
log() { echo "[r-ios] $*" >&2; }

# ---------- source ----------
fetch_r() {
  local v="$1"
  [ -f "$T/R-$v.tar.gz" ] && return 0
  curl -fsSL --retry 3 -o "$T/R-$v.tar.gz" "https://cran.r-project.org/src/base/R-4/R-$v.tar.gz"
}
if ! fetch_r "$RVER"; then
  log "R $RVER not on CRAN; trying 4.6.1"; RVER=4.6.1; fetch_r "$RVER"
fi
log "R $RVER"
unpack() { rm -rf "$1"; mkdir -p "$1"; tar -xzf "$T/R-$RVER.tar.gz" -C "$1" --strip-components 1; }

# ---------- 1. R for the Mac ----------
BREW=$(brew --prefix)
for f in gcc xz pcre2; do brew list "$f" >/dev/null 2>&1 || brew install "$f"; done
GFORTRAN=$(ls "$BREW"/bin/gfortran-* 2>/dev/null | sort -V | tail -1)
HOST_ASSET="host-R-$RVER-macos-arm64.tar.gz"
if [ ! -x "$HOST/bin/R" ] && gh release view ios-r -R "${GITHUB_REPOSITORY:-doctoralvarez/Nyxian}" --json assets -q '.assets[].name' 2>/dev/null | grep -qx "$HOST_ASSET"; then
  gh release download ios-r -R "${GITHUB_REPOSITORY:-doctoralvarez/Nyxian}" -p "$HOST_ASSET" -D "$T" --clobber
  rm -rf "$HOST"; tar -xzf "$T/$HOST_ASSET" -C /tmp
  log "R for the Mac: from the ios-r release"
fi
if [ ! -x "$HOST/bin/R" ]; then
  unpack "$SRC_HOST"
  ( cd "$SRC_HOST"
    ./configure -C --prefix="$HOST" \
      --without-x --without-aqua --disable-java --without-recommended-packages \
      --without-readline --without-tcltk --without-cairo --without-libtiff --without-jpeglib \
      --without-libpng --disable-nls --with-internal-tzcode --disable-openmp \
      CC=clang CXX=clang++ FC="$GFORTRAN" \
      CPPFLAGS="-I$BREW/include" LDFLAGS="-L$BREW/lib" \
      > "$T/host-configure.log" 2>&1 || { tail -80 "$T/host-configure.log"; tail -120 config.log; exit 1; }
    make -j "$JOBS" > "$T/host-make.log" 2>&1 || { tail -120 "$T/host-make.log"; exit 1; }
    make install > /dev/null )
  cp "$SRC_HOST/config.cache" "$HOST/host-config.cache"
  log "R for the Mac: $("$HOST/bin/R" --version | head -1)"
  # kept on the ios-r release: the next run skips this (10+ minutes)
  if [ -n "${GH_TOKEN:-}" ]; then
    R_REPO="${GITHUB_REPOSITORY:-doctoralvarez/Nyxian}"
    gh release view ios-r -R "$R_REPO" >/dev/null 2>&1 || gh release create ios-r -R "$R_REPO" --prerelease \
      --title "R for iOS (work in progress)" --notes "R built for iOS for Nyxian, and the tools used to build it." >/dev/null
    tar -czf "$T/$HOST_ASSET" -C /tmp "$(basename "$HOST")"
    gh release upload ios-r "$T/$HOST_ASSET" -R "$R_REPO" --clobber >/dev/null && log "R for the Mac kept on the ios-r release"
  fi
fi
cp "$HOST/host-config.cache" "$T/host-config.cache"

# ---------- 2. R's libraries for iOS ----------
IOS_NATIVE_FORTRAN=1 bash "$NATIVE" ensure xz pcre2 curl
IOS_NATIVE_FORTRAN=1 bash "$NATIVE" ensure flang-rt lapack
FC_WRAP=$(bash "$NATIVE" fc)
[ -x "$FC_WRAP" ] || { log "no Fortran wrapper"; exit 1; }

# ---------- 3. configure for iOS ----------
SDK=$(xcrun --sdk iphoneos --show-sdk-path)
CC_BIN=$(xcrun --sdk iphoneos -f clang)
CXX_BIN=$(xcrun --sdk iphoneos -f clang++)
IOS="-arch arm64 -isysroot $SDK -mios-version-min=$MIN_IOS"
# every C/C++ file sees nyxian_ios.h first: system()/popen() go to Nyxian Shell (iOS has neither)
IOS_INC="-include $HERE/nyxian_ios.h"

# run-time test results from the Mac (same C library); nothing about programs, flags,
# frameworks or libraries found, which differ for iOS
grep -E '^(r_cv_|ac_cv_func_|ac_cv_c_bigendian|ac_cv_sizeof_|ac_cv_alignof_|gl_cv_|am_cv_|ac_cv_have_decl_|ac_cv_type_|r_cv_func)' "$T/host-config.cache" \
  | grep -vE '^(r_cv_prog_|r_cv_path_|r_cv_header_|r_cv_check_fw|r_cv_.*FOUNDATION|r_cv_objc|r_cv_OBJC|r_cv_have_|r_cv_lapack|r_cv_zdotu|r_cv_complete_blas|r_cv_atlas|r_cv_dep_lapackblas|r_cv_icu|r_cv_cache_foundation)' \
  > "$T/ios-config.cache" || true
cat >> "$T/ios-config.cache" <<CACHE
r_cv_have_curl728=\${r_cv_have_curl728=yes}
r_cv_have_curl_https=\${r_cv_have_curl_https=yes}
r_cv_have_pcre2utf=\${r_cv_have_pcre2utf=yes}
r_cv_have_bzlib=\${r_cv_have_bzlib=yes}
r_cv_have_lzma=\${r_cv_have_lzma=yes}
r_cv_header_zlib_h=\${r_cv_header_zlib_h=yes}
r_cv_have_zstd=\${r_cv_have_zstd=no}
r_cv_have_pcre832=\${r_cv_have_pcre832=no}
r_cv_prog_fc_append_underscore=\${r_cv_prog_fc_append_underscore=yes}
r_cv_prog_fc_append_second_underscore=\${r_cv_prog_fc_append_second_underscore=no}
r_cv_prog_fc_can_run=\${r_cv_prog_fc_can_run=yes}
r_cv_prog_fc_cc_compat=\${r_cv_prog_fc_cc_compat=yes}
r_cv_prog_fc_cc_compat_complex=\${r_cv_prog_fc_cc_compat_complex=yes}
r_cv_prog_fc_char_len_t=\${r_cv_prog_fc_char_len_t=size_t}
CACHE
log "configure cache for iOS: $(wc -l < "$T/ios-config.cache") results from the Mac + presets"

unpack "$SRC_IOS"
DEPS_INC="" DEPS_LIB=""
for d in xz pcre2 curl openssl flang-rt lapack; do
  [ -d "$ROOT/$d/include" ] && DEPS_INC="$DEPS_INC -I$ROOT/$d/include"
  [ -d "$ROOT/$d/lib" ] && DEPS_LIB="$DEPS_LIB -L$ROOT/$d/lib"
done
RT_LIBS=$(cd "$ROOT/flang-rt/lib" && ls libflang_rt*.a | sed -E 's/^lib(.*)\.a$/-l\1/' | tr '\n' ' ')
( cd "$SRC_IOS"
  # cross-compiling: the build is said to be x86_64 so configure does not try to run iOS programs
  PKG_CONFIG_LIBDIR="$ROOT/xz/lib/pkgconfig:$ROOT/pcre2/lib/pkgconfig:$ROOT/curl/lib/pkgconfig:$ROOT/openssl/lib/pkgconfig" \
  PKG_CONFIG_PATH="" \
  ./configure --cache-file="$T/ios-config.cache" \
    --build=x86_64-apple-darwin20 --host=aarch64-apple-darwin20 \
    --prefix=/R --enable-R-shlib --disable-R-static-lib \
    --without-x --without-aqua --disable-java --without-recommended-packages \
    --without-readline --without-tcltk --without-cairo --without-libtiff --without-jpeglib \
    --without-libpng --disable-nls --with-internal-tzcode --disable-openmp --without-ICU \
    --with-internal-xdr \
    CC="$CC_BIN $IOS" CXX="$CXX_BIN $IOS" OBJC="$CC_BIN $IOS" FC="$FC_WRAP" \
    CPPFLAGS="$DEPS_INC" LDFLAGS="$DEPS_LIB" \
    FLIBS="-L$ROOT/flang-rt/lib $RT_LIBS -lc++" \
    LIBS="-lssl -lcrypto -lz" \
    R_EXE="$HOST/bin/R" \
    > "$T/ios-configure.log" 2>&1 || {
      tail -30 "$T/ios-configure.log"
      # the failing checks with their compiler/linker output (confdefs at the end of config.log says nothing)
      echo "---- config.log: the last checks"
      awk '/^configure:[0-9]+: checking /{n++} {buf[n]=buf[n] $0 "\n"} END{for(i=n-3;i<=n;i++) if(i>0) printf "%s", buf[i]}' config.log | head -200
      echo "---- config.log: inflateInit2_"
      grep -n -A25 "checking for inflateInit2_" config.log | head -60
      exit 1; }
  tail -40 "$T/ios-configure.log"
  # only for the build (configure's own checks must not see it): C, C++ and Objective-C flags
  for mk in Makeconf etc/Makeconf; do
    [ -f "$mk" ] || continue
    /usr/bin/sed -i '' -E "s|^(CFLAGS = .*)$|\1 $IOS_INC|; s|^(CXXFLAGS = .*)$|\1 $IOS_INC|; s|^(CXX1[147]FLAGS = .*)$|\1 $IOS_INC|; s|^(CXX2[03]FLAGS = .*)$|\1 $IOS_INC|; s|^(OBJCFLAGS = .*)$|\1 $IOS_INC|" "$mk"
  done
  grep -E "^(CFLAGS|CXXFLAGS) =" Makeconf
)
log "configured for iOS"

# ---------- 4. the native parts for iOS ----------
# R's own build runs R many times (base packages' R code, lazy-load databases, help); R for
# iOS cannot run on the Mac. Those parts do not depend on the platform, so they come from R
# for the Mac (same version, same options); only what is compiled is built here for iOS.
( cd "$SRC_IOS"
  make -k -j "$JOBS" > "$T/ios-make.log" 2>&1 || log "make -k: some steps need R running (done with R for the Mac below)"
  # libR, its BLAS/LAPACK and modules (internet, lapack…)
  make -C src/main -j "$JOBS" >> "$T/ios-make.log" 2>&1 || { log "libR did not build:"; grep -E "error:|Undefined" "$T/ios-make.log" | sort -u | head -60; exit 1; }
  make -C src/modules -j "$JOBS" >> "$T/ios-make.log" 2>&1 || { log "modules did not build:"; grep -E "error:|Undefined" "$T/ios-make.log" | sort -u | head -60; exit 1; }
  # each base package's compiled code (stats, graphics, grDevices, utils, methods, tools…)
  failed=""
  for d in src/library/*/src; do
    pkg=$(basename "$(dirname "$d")")
    [ -f "$d/Makefile" ] || continue
    [ "$pkg" = tcltk ] && continue   # Tcl/Tk: no windows of its own on iOS
    if ! make -C "$d" -j "$JOBS" >> "$T/ios-make.log" 2>&1; then failed="$failed $pkg"; fi
  done
  [ -z "$failed" ] || { log "packages whose compiled code did not build:$failed"; grep -E "error:|Undefined" "$T/ios-make.log" | sort -u | head -80; exit 1; }
)
log "compiled for iOS"

# ---------- 5. R_HOME for iOS ----------
RH="$OUT/R"
rm -rf "$RH"; mkdir -p "$RH"
cp -R "$HOST/lib/R/." "$RH/"
# compiled parts: from the iOS build
rm -rf "$RH/bin/exec"
# programs of the Mac (Rscript…): Nyxian's R and Rscript commands take their place on iOS
find "$RH/bin" -type f | while read -r f; do if file "$f" | grep -q "Mach-O"; then rm -f "$f"; fi; done
cp -f "$SRC_IOS"/lib/*.dylib "$RH/lib/"
mkdir -p "$RH/modules"; cp -f "$SRC_IOS"/modules/*.so "$RH/modules/" 2>/dev/null || true
for libs in "$SRC_IOS"/library/*/libs; do
  pkg=$(basename "$(dirname "$libs")")
  mkdir -p "$RH/library/$pkg/libs"; cp -f "$libs"/*.so "$RH/library/$pkg/libs/"
done
cp -f "$SRC_IOS/etc/Makeconf" "$RH/etc/Makeconf"
cp -R "$SRC_IOS/include/." "$RH/include/"
cp -f "$HERE/Rprofile.site" "$RH/etc/Rprofile.site"
# every Mach-O must be for iOS (none left from the Mac)
bad=""
while IFS= read -r -d '' f; do
  if file "$f" | grep -q "Mach-O"; then
    plat=$(xcrun vtool -show-build "$f" 2>/dev/null | awk '/platform/{print $2; exit}')
    [ "$plat" = "IOS" ] || bad="$bad\n  $f ($plat)"
  fi
done < <(find "$RH" -type f \( -name '*.so' -o -name '*.dylib' -o -perm -111 \) -print0)
if [ -n "$bad" ]; then log "not built for iOS:"; printf "$bad\n"; exit 1; fi
log "R_HOME for iOS: $(du -sh "$RH" | cut -f1); compiled parts:"
( cd "$RH" && find . -name '*.so' -o -name '*.dylib' | sort )

# kept on the ios-r release
TAR="r-ios-$RVER-arm64.tar.gz"
tar -czf "$OUT/$TAR" -C "$OUT" R
if [ -n "${GH_TOKEN:-}" ]; then
  gh release upload ios-r "$OUT/$TAR" -R "${GITHUB_REPOSITORY:-doctoralvarez/Nyxian}" --clobber >/dev/null && log "published $TAR on the ios-r release"
fi
