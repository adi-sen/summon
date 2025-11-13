#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

cargo build -p ffi
cbindgen --crate ffi --output src/swift/ffi.h

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
  -import-objc-header src/swift/ffi.h \
  -Xlinker -rpath -Xlinker @executable_path/../lib \
  -framework SwiftUI \
  -framework AppKit \
  -framework Carbon \
  -target arm64-apple-macosx12.0 \
  $(find src/swift -name "*.swift")
