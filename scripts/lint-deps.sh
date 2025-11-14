#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
FAIL=0

echo "=== Security Audit ==="
cargo audit --deny warnings 2>&1 && echo "PASS" || { echo "FAIL"; FAIL=1; }

echo -e "\n=== Unused Dependencies ==="
cargo machete 2>&1 && echo "PASS" || echo "INFO: cargo machete --fix"

echo -e "\n=== Policy Check ==="
cargo deny check 2>&1 && echo "PASS" || { echo "FAIL"; FAIL=1; }

echo -e "\n=== Analysis ==="
echo "Direct: $(cargo tree --depth 0 -e normal | tail -n +2 | wc -l | tr -d ' ')"
echo "Total: $(cargo tree -e normal --prefix none | sort -u | wc -l | tr -d ' ')"

echo ""
[ "$FAIL" -eq 0 ] && echo "SUCCESS" || { echo "FAILED"; exit 1; }
