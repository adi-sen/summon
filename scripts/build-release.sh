#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

cargo build --release -p ffi
cbindgen --crate ffi --output src/swift/ffi.h
swift build -c release --jobs 8

strip -x .build/release/Summon
strip -x target/release/libffi.dylib

mkdir -p .build/macos/lib
cp target/release/libffi.dylib .build/macos/lib/
cp .build/release/Summon .build/macos/Summon
