#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

cargo build --release -p ffi
cbindgen --crate ffi --output src/swift/ffi.h
swift build -c release --jobs 8

strip -x .build/release/Summon
mkdir -p .build/macos
cp .build/release/Summon .build/macos/Summon
