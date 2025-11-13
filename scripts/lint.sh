#!/usr/bin/env bash
set -uo pipefail

cd "$(dirname "$0")/.."

FAIL=0

echo "=== Rust Formatting ==="
if cargo +nightly fmt --all -- --check 2>&1 | rg "^Diff" > /dev/null; then
    echo "FAIL: Run 'cargo +nightly fmt --all'"
    FAIL=1
else
    echo "PASS"
fi

echo ""
echo "=== Rust Clippy ==="
CLIPPY_OUT=$(mktemp)
cargo clippy --workspace --all-targets -- -D warnings 2>&1 | tee "$CLIPPY_OUT"
if rg -q "^error:" "$CLIPPY_OUT"; then
    ERRORS=$(rg "^error:" "$CLIPPY_OUT" | wc -l | tr -d ' ')
    echo "FAIL: $ERRORS errors"
    FAIL=1
else
    WARNINGS=$(rg "^warning:" "$CLIPPY_OUT" | wc -l | tr -d ' ')
    [ "$WARNINGS" -gt 0 ] && echo "WARN: $WARNINGS warnings" || echo "PASS"
fi
rm -f "$CLIPPY_OUT"

echo ""
echo "=== Rust Tests ==="
if cargo test --workspace --quiet 2>&1 | rg "test result:" | rg -q "FAILED"; then
    echo "FAIL"
    FAIL=1
else
    echo "PASS"
fi

echo ""
echo "=== Swift Formatting ==="
if command -v swiftformat &> /dev/null; then
    swiftformat --lint src/swift 2>&1 | rg -q "error|warning" && swiftformat src/swift
    echo "PASS (auto-fixed)"
else
    echo "SKIP: swiftformat not installed"
fi

echo ""
echo "=== Swift Linting ==="
if command -v swiftlint &> /dev/null; then
    SWIFT_OUT=$(mktemp)
    swiftlint lint --quiet src/swift 2>&1 | tee "$SWIFT_OUT"
    VIOLATIONS=$(rg "^\S+:\d+:\d+:" "$SWIFT_OUT" | wc -l | tr -d ' ')
    rm -f "$SWIFT_OUT"
    [ "$VIOLATIONS" -gt 0 ] && echo "WARN: $VIOLATIONS violations" || echo "PASS"
else
    echo "SKIP: swiftlint not installed"
fi

echo ""
echo "=== Code Quality ==="
DBG=$(rg "dbg!" src/rust --type rust 2>/dev/null | wc -l | tr -d ' ')
[ "$DBG" -gt 0 ] && echo "FAIL: $DBG dbg! macros found" && FAIL=1 || echo "dbg!: PASS"

TODO=$(rg "TODO|FIXME" src/ --type rust --type swift -i 2>/dev/null | wc -l | tr -d ' ')
[ "$TODO" -gt 0 ] && echo "INFO: $TODO TODO/FIXME comments" || true

echo ""
[ "$FAIL" -eq 0 ] && echo "SUCCESS" && exit 0 || echo "FAILED" && exit 1
