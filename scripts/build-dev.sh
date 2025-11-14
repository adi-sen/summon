#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

cargo build -p ffi
cbindgen --crate ffi --output src/swift/ffi.h
swift build -c debug --jobs 8
cp .build/debug/Summon .build/macos-dev/Summon
