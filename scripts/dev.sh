#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

"$SCRIPT_DIR/build.sh" dev

echo ""
echo "Starting Summon..."
echo "Press Ctrl+C to stop"
echo ""

cd "$PROJECT_ROOT/.build/macos-dev"
exec ./Summon
