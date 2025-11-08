#!/usr/bin/env bash
set -euo pipefail

# Development script: fast build and run

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# Use fast dev build (no optimizations)
"$SCRIPT_DIR/build-dev.sh"

echo ""
echo -e "${BLUE}Starting Summon...${NC}"
echo -e "${GREEN}Press Ctrl+C to stop${NC}"
echo ""

cd "$PROJECT_ROOT/.build/macos-dev"
exec ./Summon
