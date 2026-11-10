#!/bin/bash
# Fork doctoralvarez/Nyxian — version 1.1.1
# Changelog:
#  - 1.1.1 (2026-11-10): the export check reads nm's output from a file (grep -q
#    in a pipe broke nm's output under pipefail).
#  - 1.1.0 (2026-11-10): on iOS miniJVM is a library (lib/libminijvm.dylib,
#    its main renamed minijvm_main) loaded by a tiny `java` launcher, like
#    Node.js: Nyxian refused to start the big miniJVM executable from
#    Nyxian Shell ("Operation not permitted").
#  - 1.0.1 (2026-11-10): the iOS build leaves out sljit (miniJVM's JIT code
#    generator): miniJVM turns its JIT off on iOS, so it is not used there,
#    and it did not compile for iOS.
#  - 1.0.0 (2026-11-10): packs Java for iOS as Shared/java-ios.zip: miniJVM
#    (an interpreter in C; miniJVM turns its JIT off on iOS), its class
#    library (Java 8 subset) and the janino-continue compiler (javac). With
#    TEST_DIR set it also builds a miniJVM for this Mac there, for the
#    Nyxian Shell test (HOST_ONLY=1: only that).
set -euo pipefail

MINIJVM_REPO="https://github.com/digitalgust/miniJVM.git"
MINIJVM_COMMIT="76f904ea4008a8058db5155bf5ee2cfe94d19e60"
JANINO_COMMIT="3f8689e47eb325601e6305487df1b05af0236c45"
JANINO_SHA="68312504531e7469335a347d2e27ae07d1e8077fbc6ca17b044c442365b1c3a6"
COMPILER_SHA="cdd61aae4a2562c3e1f90b60091bac3fec1ad4c360b477ab0a3db52a7cd234cf"

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$ROOT/Shared/java-ios.zip"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo ">>> miniJVM $MINIJVM_COMMIT"
git init -q "$WORK/mjvm"
git -C "$WORK/mjvm" fetch -q --depth 1 "$MINIJVM_REPO" "$MINIJVM_COMMIT"
git -C "$WORK/mjvm" checkout -q FETCH_HEAD
CSRC="$WORK/mjvm/minijvm/c"

# Nyxian's changes: keep the folder the program was started in (not the binary's),
# and [INFO] lines only with MINIJVM_VERBOSE=1
sed -i '' '/set_working_dir_to_startup_dir(startup_dir);/d' "$CSRC/main.c"
grep -rl 'jvm_printf("\[INFO\]' "$CSRC" | while read -r f; do
  sed -i '' 's/jvm_printf("\[INFO\]/jvm_info_printf("[INFO]/g' "$f"
done
cat > "$WORK/nyxian_quiet.h" <<'EOF'
#include <stdlib.h>
#define jvm_info_printf(...) ((void)(getenv("MINIJVM_VERBOSE") && jvm_printf(__VA_ARGS__)))
EOF

SRCLIST=$(find "$CSRC" -type f -name "*.c" -not -path "$CSRC/utils/sljit/*" -not -path "$CSRC/utils/mimalloc/src/*" -not -path "$CSRC/cmake-*" -not -path "$CSRC/.*")
INCLUDES=(-I"$CSRC" -I"$CSRC/jvm" -I"$CSRC/utils/" -I"$CSRC/utils/sljit/" -I"$CSRC/utils/https/" -I"$CSRC/utils/https/mbedtls/include/" -I"$CSRC/utils/mimalloc/include/")
build() {  # output, extra sources, then compiler and flags
  local output="$1" extra="$2"; shift 2
  # shellcheck disable=SC2086
  "$@" -O2 -w -include "$WORK/nyxian_quiet.h" "${INCLUDES[@]}" -o "$output" $SRCLIST $extra \
    "$CSRC/utils/mimalloc/src/static.c" -lpthread -lm
}

HOME_DIR="$WORK/java"
mkdir -p "$HOME_DIR/bin" "$HOME_DIR/lib"
echo ">>> class library (minijvm_rt.jar)"
mkdir -p "$WORK/classes"
find "$WORK/mjvm/minijvm/java/src/main/java" -name "*.java" > "$WORK/sources.txt"
javac --release 8 -nowarn -encoding utf-8 -d "$WORK/classes" @"$WORK/sources.txt" 2>&1 | grep -v "^Note:" || true
if [ -d "$WORK/mjvm/minijvm/java/src/main/resource" ]; then cp -R "$WORK/mjvm/minijvm/java/src/main/resource/." "$WORK/classes/"; fi
(cd "$WORK/classes" && jar cf "$HOME_DIR/lib/minijvm_rt.jar" .)

echo ">>> janino-continue (javac)"
for name in janino commons-compiler; do
  curl -fsSL --retry 6 --retry-delay 10 --retry-all-errors -o "$HOME_DIR/lib/$name.jar" \
    "https://github.com/digitalgust/digitalgust.github.io/raw/$JANINO_COMMIT/lib/$name.jar"
done
echo "$JANINO_SHA  $HOME_DIR/lib/janino.jar" | shasum -a 256 -c -
echo "$COMPILER_SHA  $HOME_DIR/lib/commons-compiler.jar" | shasum -a 256 -c -

cp "$WORK/mjvm/LICENSE" "$HOME_DIR/LICENSE"
cp "$WORK/mjvm/minijvm/java/CLASSPATH_EXCEPTION" "$WORK/mjvm/minijvm/java/MIT_LICENSE" "$HOME_DIR/" 2>/dev/null || true
echo "miniJVM $MINIJVM_COMMIT" > "$HOME_DIR/VERSION"

if [ -n "${TEST_DIR:-}" ]; then
  echo ">>> miniJVM for this Mac (shell test) in $TEST_DIR"
  mkdir -p "$TEST_DIR/bin" "$TEST_DIR/lib"
  build "$TEST_DIR/bin/java" "$CSRC/utils/sljit/sljitLir.c" clang
  cp "$HOME_DIR"/lib/*.jar "$TEST_DIR/lib/"
  [ "${HOST_ONLY:-}" = "1" ] && exit 0
fi

echo ">>> miniJVM for iOS (arm64, interpreter only: no sljit) as lib/libminijvm.dylib"
sed -i '' 's/^int main(int argc, char \*\*argv) {/int minijvm_main(int argc, char **argv) {/' "$CSRC/main.c"
grep -q '^int minijvm_main(' "$CSRC/main.c" || { echo "main() of miniJVM not found"; exit 1; }
IOS_CC=(xcrun -sdk iphoneos clang -arch arm64 -miphoneos-version-min=16.0)
build "$HOME_DIR/lib/libminijvm.dylib" "" "${IOS_CC[@]}" -dynamiclib -install_name @loader_path/libminijvm.dylib
nm -gU "$HOME_DIR/lib/libminijvm.dylib" > "$WORK/exports.txt"
grep ' _minijvm_main$' "$WORK/exports.txt" > /dev/null || { echo "minijvm_main is not exported"; exit 1; }
# Nyxian signs it again on the device
codesign --remove-signature "$HOME_DIR/lib/libminijvm.dylib" 2>/dev/null || true
echo ">>> java launcher"
"${IOS_CC[@]}" -O2 -o "$HOME_DIR/bin/java" "$ROOT/tools/fork/java_launcher.c"

mkdir -p "$ROOT/Shared"
rm -f "$OUT"
(cd "$WORK" && zip -qry "$OUT" java)
ls -la "$OUT"
