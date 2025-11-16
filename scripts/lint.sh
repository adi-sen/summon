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
    cargo clippy --workspace --all-targets \
        --exclude search_engine_bridge \
        --exclude calculator_bridge \
        --exclude settings_bridge \
        --exclude clipboard_bridge \
        --exclude snippet_matcher_bridge \
        --exclude snippet_storage_bridge \
        --exclude app_storage_bridge \
        --exclude action_manager_bridge \
        --exclude file_indexer_bridge \
        -- -D warnings 2>&1 | tee "$TMP"
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
    if cargo test --workspace --quiet \
        --exclude search_engine_bridge \
        --exclude calculator_bridge \
        --exclude settings_bridge \
        --exclude clipboard_bridge \
        --exclude snippet_matcher_bridge \
        --exclude snippet_storage_bridge \
        --exclude app_storage_bridge \
        --exclude action_manager_bridge \
        --exclude file_indexer_bridge \
        2>&1 | rg "test result:" | rg -q "FAILED"; then
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
        if swiftlint lint --strict --quiet src/swift 2>&1; then
            echo "PASS"
        else
            echo "FAIL (warnings treated as errors)"
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

echo -e "\n=== Security Audit ==="
if [ -d "src/rust" ]; then
    if command -v cargo-audit &>/dev/null; then
        if cargo audit --deny warnings 2>&1; then
            echo "PASS"
        else
            echo "FAIL"
            FAIL=1
        fi
    else
        echo "SKIP (cargo-audit not installed)"
    fi
else
    echo "SKIP (no src/rust directory)"
fi

echo -e "\n=== Unused Dependencies ==="
if [ -d "src/rust" ]; then
    if command -v cargo-machete &>/dev/null; then
        if cargo machete 2>&1 | rg -q "didn't find any unused"; then
            echo "PASS"
        else
            echo "FAIL: Run 'cargo machete --fix' to remove unused deps"
            FAIL=1
        fi
    else
        echo "SKIP (cargo-machete not installed)"
    fi
else
    echo "SKIP (no src/rust directory)"
fi

echo -e "\n=== Dependency Policy ==="
if [ -d "src/rust" ]; then
    if command -v cargo-deny &>/dev/null; then
        TMP=$(mktemp)
        if cargo deny check 2>&1 | tee "$TMP" | rg -q "^error"; then
            echo "FAIL"
            FAIL=1
        else
            echo "PASS"
        fi
        rm -f "$TMP"
    else
        echo "SKIP (cargo-deny not installed)"
    fi
else
    echo "SKIP (no src/rust directory)"
fi

echo -e "\n=== Dependency Analysis ==="
if [ -d "src/rust" ]; then
    DIRECT=$(cargo tree --depth 0 -e normal 2>/dev/null | tail -n +2 | wc -l | tr -d ' ')
    TOTAL=$(cargo tree -e normal --prefix none 2>/dev/null | sort -u | wc -l | tr -d ' ')
    echo "Direct: $DIRECT"
    echo "Total: $TOTAL"
    echo "PASS"
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
