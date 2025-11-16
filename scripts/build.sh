#!/usr/bin/env bash
set -euo pipefail

MODE=${1:-dev}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

case "$MODE" in
	dev)
		CARGO_FLAGS=""
		SWIFT_FLAGS="-c debug"
		OUTPUT_DIR=".build/macos-dev"
		BINARY=".build/debug/Summon"
		;;
	release)
		CARGO_FLAGS="--release"
		SWIFT_FLAGS="-c release"
		OUTPUT_DIR=".build/macos"
		BINARY=".build/release/Summon"
		;;
	*)
		echo "Usage: $0 [dev|release]"
		exit 1
		;;
esac

MACOSX_DEPLOYMENT_TARGET=12.0 cargo build $CARGO_FLAGS -p ffi &
CARGO_PID=$!
swift build $SWIFT_FLAGS --jobs 8 &
SWIFT_PID=$!
wait $CARGO_PID $SWIFT_PID

if [ "$MODE" = "release" ]; then
	strip -x "$BINARY"
fi

mkdir -p "$OUTPUT_DIR"
cp "$BINARY" "$OUTPUT_DIR/Summon"
