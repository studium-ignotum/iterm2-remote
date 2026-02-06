#!/bin/bash
#
# Terminal Remote - Start
#
# Starts relay-server + mac-client (which auto-starts cloudflared tunnel).
# The tunnel URL appears in the menu bar and can be copied from there.
#
# Usage: ./scripts/start.sh
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# ── Preflight ────────────────────────────────────────────────

RELAY_BIN="$PROJECT_ROOT/relay-server/target/release/relay-server"
CLIENT_BIN="$PROJECT_ROOT/mac-client/target/release/mac-client"

if [ ! -f "$RELAY_BIN" ] || [ ! -f "$CLIENT_BIN" ]; then
    echo -e "${RED}Binaries not found. Run setup first:${NC}"
    echo "  ./scripts/setup.sh"
    exit 1
fi

if ! command -v tmux &>/dev/null; then
    echo -e "${RED}tmux is required. Install with: brew install tmux${NC}"
    exit 1
fi

# ── Kill old instances ───────────────────────────────────────

pkill -f "target/.*relay-server" 2>/dev/null || true
pkill -f "target/.*mac-client" 2>/dev/null || true
pkill cloudflared 2>/dev/null || true
sleep 0.3

# ── Cleanup on exit ──────────────────────────────────────────

cleanup() {
    echo ""
    echo -e "${YELLOW}Stopping...${NC}"
    pkill -f "target/.*relay-server" 2>/dev/null || true
    pkill -f "target/.*mac-client" 2>/dev/null || true
    pkill cloudflared 2>/dev/null || true
    exit 0
}
trap cleanup SIGINT SIGTERM

# ── Start relay-server ───────────────────────────────────────

echo -e "${BLUE}> Starting relay-server...${NC}"
"$RELAY_BIN" &
RELAY_PID=$!
sleep 0.5

if kill -0 "$RELAY_PID" 2>/dev/null; then
    echo -e "${GREEN}  relay-server running (pid $RELAY_PID)${NC}"
else
    echo -e "${RED}  relay-server failed to start${NC}"
    exit 1
fi

# ── Start mac-client (includes cloudflared tunnel) ───────────

echo -e "${BLUE}> Starting mac-client...${NC}"
"$CLIENT_BIN" &
CLIENT_PID=$!
sleep 1

if kill -0 "$CLIENT_PID" 2>/dev/null; then
    echo -e "${GREEN}  mac-client running (pid $CLIENT_PID)${NC}"
else
    echo -e "${RED}  mac-client failed to start${NC}"
    exit 1
fi

# ── Ready ────────────────────────────────────────────────────

echo ""
echo -e "${GREEN}========================================"
echo "  Terminal Remote is running"
echo "========================================${NC}"
echo ""
echo "  Check the menu bar icon for:"
echo "    - Tunnel URL (public access)"
echo "    - Session code (for browser auth)"
echo ""
echo "  Copy URL -> open on phone -> enter code -> done"
echo ""
echo -e "${YELLOW}  Press Ctrl+C to stop${NC}"
echo ""

# Wait
wait
