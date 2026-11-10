#!/bin/bash
# Fork doctoralvarez/Nyxian — version 1.0.0
# Changelog:
#  - 1.0.0 (2026-11-10): packs Node.js for iOS as Shared/node-ios.zip: the
#    NodeMobile library of nodejs-mobile (Node 18, V8 without JIT — the
#    standard iOS build), npm and corepack (from the same Node version for
#    macOS) and the `node` launcher. Nyxian unpacks and signs it on the
#    device, like Python.
set -euo pipefail

NODE_VER="${NODE_VER:-18.20.4}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$ROOT/Shared/node-ios.zip"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

download() {  # url file [gh-repo tag pattern]
  if ! curl -fsSL --retry 8 --retry-delay 15 --retry-all-errors -o "$2" "$1"; then
    [ -n "${3:-}" ] || return 1
    echo ">>> direct download failed, trying gh release download"
    gh release download "$4" -R "$3" -p "$5" -O "$2" --clobber
  fi
}

echo ">>> nodejs-mobile v$NODE_VER for iOS"
download "https://github.com/nodejs-mobile/nodejs-mobile/releases/download/v${NODE_VER}/nodejs-mobile-v${NODE_VER}-ios.zip" \
  "$WORK/mobile.zip" nodejs-mobile/nodejs-mobile "v${NODE_VER}" "nodejs-mobile-v${NODE_VER}-ios.zip"
unzip -q "$WORK/mobile.zip" 'NodeMobile.xcframework/ios-arm64/*' -d "$WORK/mobile"
LIB="$WORK/mobile/NodeMobile.xcframework/ios-arm64/NodeMobile.framework/NodeMobile"
[ -f "$LIB" ] || { echo "no ios-arm64 NodeMobile"; exit 1; }

echo ">>> npm and corepack (Node v$NODE_VER for macOS)"
download "https://nodejs.org/dist/v${NODE_VER}/node-v${NODE_VER}-darwin-arm64.tar.gz" "$WORK/node.tar.gz"
tar -xzf "$WORK/node.tar.gz" -C "$WORK"
DIST="$WORK/node-v${NODE_VER}-darwin-arm64"

HOME_DIR="$WORK/node"
mkdir -p "$HOME_DIR/bin" "$HOME_DIR/lib"
cp "$LIB" "$HOME_DIR/lib/NodeMobile"
# loaded by absolute path: its own install name only has to be its own
install_name_tool -id "@loader_path/NodeMobile" "$HOME_DIR/lib/NodeMobile" 2>/dev/null || true
# Nyxian signs it again on the device
codesign --remove-signature "$HOME_DIR/lib/NodeMobile" 2>/dev/null || true
cp -R "$DIST/lib/node_modules" "$HOME_DIR/lib/node_modules"
# docs and man pages are not needed on the device
rm -rf "$HOME_DIR"/lib/node_modules/npm/{docs,man,changelogs} 2>/dev/null || true
cp "$DIST/LICENSE" "$HOME_DIR/LICENSE"

echo ">>> node launcher"
xcrun -sdk iphoneos clang -arch arm64 -miphoneos-version-min=16.0 -O2 \
  -o "$HOME_DIR/bin/node" "$ROOT/tools/fork/node_launcher.c"

echo "$NODE_VER" > "$HOME_DIR/VERSION"
"$DIST/bin/node" "$DIST/lib/node_modules/npm/bin/npm-cli.js" --version > "$HOME_DIR/NPM_VERSION" 2>/dev/null || true
echo "  node $NODE_VER · npm $(cat "$HOME_DIR/NPM_VERSION" 2>/dev/null)"

mkdir -p "$ROOT/Shared"
rm -f "$OUT"
(cd "$WORK" && zip -qry "$OUT" node)
ls -la "$OUT"
SIZE=$(stat -f%z "$OUT")
[ "$SIZE" -lt 150000000 ] || { echo "node-ios.zip is $SIZE bytes: refusing"; rm -f "$OUT"; exit 1; }
