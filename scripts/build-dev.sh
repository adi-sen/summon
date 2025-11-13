#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

cargo build -p ffi
cbindgen --crate ffi --output src/swift/ffi.h
swift build -c debug --jobs 8

mkdir -p .build/macos-dev/lib
cp target/debug/libffi.dylib .build/macos-dev/lib/
cp .build/debug/Summon .build/macos-dev/Summon
