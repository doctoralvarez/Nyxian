#!/bin/bash
# Fork doctoralvarez/Nyxian — version 0.1.1
# Changelog:
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
HOST="$T/host-R"            # R for the Mac
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
  log "R for the Mac: $("$HOST/bin/R" --version | head -1)"
fi
cp "$SRC_HOST/config.cache" "$T/host-config.cache"

# ---------- 2. R's libraries for iOS ----------
IOS_NATIVE_FORTRAN=1 bash "$NATIVE" ensure xz pcre2 curl
IOS_NATIVE_FORTRAN=1 bash "$NATIVE" ensure flang-rt
FC_WRAP=$(bash "$NATIVE" fc)
[ -x "$FC_WRAP" ] || { log "no Fortran wrapper"; exit 1; }

# ---------- 3. configure for iOS ----------
SDK=$(xcrun --sdk iphoneos --show-sdk-path)
CC_BIN=$(xcrun --sdk iphoneos -f clang)
CXX_BIN=$(xcrun --sdk iphoneos -f clang++)
IOS="-arch arm64 -isysroot $SDK -mios-version-min=$MIN_IOS"

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
for d in xz pcre2 curl openssl flang-rt; do
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
    > "$T/ios-configure.log" 2>&1 || { tail -60 "$T/ios-configure.log"; echo "---- config.log"; tail -150 config.log; exit 1; }
  tail -40 "$T/ios-configure.log"
)
log "configured for iOS"

# ---------- 4. compile what builds ----------
( cd "$SRC_IOS"
  make -j "$JOBS" > "$T/ios-make.log" 2>&1 || { log "make stopped:"; tail -100 "$T/ios-make.log"; exit 1; } )
log "make finished"
ls -la "$SRC_IOS/lib" || true
