#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

cargo build --release -p ffi

mkdir -p .build/macos/lib
cp target/release/libffi.dylib .build/macos/lib/

swiftc \
  -o .build/macos/Summon \
  -emit-executable \
  -module-name Summon \
  -O \
  -whole-module-optimization \
  -L target/release \
  -lffi \
  -Xlinker -rpath -Xlinker @executable_path/../lib \
  -framework SwiftUI \
  -framework AppKit \
  -framework Carbon \
  -target arm64-apple-macosx12.0 \
  $(find src/swift -name "*.swift")
