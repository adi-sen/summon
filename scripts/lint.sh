#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

cargo +nightly fmt --all
cargo clippy --all-targets --all-features -- -D warnings
swiftlint lint --quiet src/swift || true
swiftformat .
