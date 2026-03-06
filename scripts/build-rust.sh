#!/bin/bash
set -e

cd "$(dirname "$0")/../spotti-core"

echo "Building for aarch64-apple-darwin..."
cargo build --target aarch64-apple-darwin --release

BRIDGE_DIR="../SpottiApp/Spotti/Spotti/Bridge"
mkdir -p "$BRIDGE_DIR"

echo "Copying header..."
cp include/spotti_core.h "$BRIDGE_DIR/"

echo "Copying library..."
cp target/aarch64-apple-darwin/release/libspotti_core.a "$BRIDGE_DIR/"

echo "Done."
echo "  Library: $BRIDGE_DIR/libspotti_core.a"
echo "  Header:  $BRIDGE_DIR/spotti_core.h"
