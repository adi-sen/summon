#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
FAIL=0

echo "=== Rust Formatting ==="
cargo +nightly fmt --all -- --check 2>&1 | rg "^Diff" && { echo "FAIL"; FAIL=1; } || echo "PASS"

echo -e "\n=== Clippy ==="
TMP=$(mktemp)
cargo clippy --workspace --all-targets -- -D warnings 2>&1 | tee "$TMP"
rg -q "^error:" "$TMP" && { echo "FAIL"; FAIL=1; } || echo "PASS"
rm -f "$TMP"

echo -e "\n=== Tests ==="
cargo test --workspace --quiet 2>&1 | rg "test result:" | rg -q "FAILED" && { echo "FAIL"; FAIL=1; } || echo "PASS"

echo -e "\n=== Swift ==="
command -v swiftformat &>/dev/null && { swiftformat --lint src/swift 2>&1 | rg -q "error|warning" && swiftformat src/swift; echo "PASS"; } || echo "SKIP"
command -v swiftlint &>/dev/null && swiftlint lint --quiet src/swift || echo "SKIP"

echo -e "\n=== Quality ==="
DBG=$(rg "dbg!" src/rust --type rust 2>/dev/null | wc -l | tr -d ' ')
[ "$DBG" -gt 0 ] && { echo "FAIL: $DBG dbg! found"; FAIL=1; } || echo "PASS"

echo ""
[ "$FAIL" -eq 0 ] && echo "SUCCESS" || { echo "FAILED"; exit 1; }
