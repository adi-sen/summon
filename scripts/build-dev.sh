#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

cargo build -p ffi

mkdir -p .build/macos-dev/lib
cp target/debug/libffi.dylib .build/macos-dev/lib/

swiftc \
  -o .build/macos-dev/Summon \
  -emit-executable \
  -module-name Summon \
  -Onone \
  -j $(sysctl -n hw.ncpu) \
  -L target/debug \
  -lffi \
  -Xlinker -rpath -Xlinker @executable_path/../lib \
  -framework SwiftUI \
  -framework AppKit \
  -framework Carbon \
  -target arm64-apple-macosx12.0 \
  $(find src/swift -name "*.swift")
