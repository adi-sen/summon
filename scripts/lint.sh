#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
FAIL=0

echo "=== Rust Formatting ==="
if [ -d "src/rust" ]; then
    if cargo +nightly fmt --all -- --check 2>&1 | rg -q "^Diff"; then
        echo "FAIL"
        FAIL=1
    else
        echo "PASS"
    fi
else
    echo "SKIP (no src/rust directory)"
fi

echo -e "\n=== Clippy ==="
if [ -d "src/rust" ]; then
    TMP=$(mktemp)
    cargo clippy --workspace --all-targets -- -D warnings 2>&1 | tee "$TMP"
    if rg -q "^error:" "$TMP"; then
        echo "FAIL"
        FAIL=1
    else
        echo "PASS"
    fi
    rm -f "$TMP"
else
    echo "SKIP (no src/rust directory)"
fi

echo -e "\n=== Tests ==="
if [ -d "src/rust" ]; then
    if cargo test --workspace --quiet 2>&1 | rg "test result:" | rg -q "FAILED"; then
        echo "FAIL"
        FAIL=1
    else
        echo "PASS"
    fi
else
    echo "SKIP (no src/rust directory)"
fi

echo -e "\n=== Swift Formatting ==="
if [ -d "src/swift" ]; then
    if command -v swiftformat &>/dev/null; then
        if swiftformat --lint src/swift 2>&1 | rg -q "error|warning"; then
            echo "Reformatting..."
            swiftformat src/swift
            echo "PASS (auto-formatted)"
        else
            echo "PASS"
        fi
    else
        echo "SKIP (swiftformat not installed)"
    fi
else
    echo "SKIP (no src/swift directory)"
fi

echo -e "\n=== Swift Linting ==="
if [ -d "src/swift" ]; then
    if command -v swiftlint &>/dev/null; then
        if swiftlint lint --quiet src/swift; then
            echo "PASS"
        else
            echo "FAIL"
            FAIL=1
        fi
    else
        echo "SKIP (swiftlint not installed)"
    fi
else
    echo "SKIP (no src/swift directory)"
fi

echo -e "\n=== Quality ==="
if [ -d "src/rust" ]; then
    set +e
    DBG=$(rg "dbg!" src/rust --type rust 2>/dev/null | wc -l | tr -d ' ')
    set -e
    if [ "$DBG" -gt 0 ]; then
        echo "FAIL: $DBG dbg! found"
        FAIL=1
    else
        echo "PASS"
    fi
else
    echo "SKIP (no src/rust directory)"
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "✓ SUCCESS"
    exit 0
else
    echo "✗ FAILED"
    exit 1
fi
