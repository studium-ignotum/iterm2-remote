#!/bin/bash
#
# Terminal Remote - Setup & Build
#
# One command to install deps, build everything, and be ready to run.
# Usage: ./scripts/setup.sh
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

echo -e "${BLUE}"
echo "========================================"
echo "  Terminal Remote - Setup"
echo "========================================"
echo -e "${NC}"

# ── Check prerequisites ──────────────────────────────────────

echo -e "${BLUE}> Checking prerequisites...${NC}"
MISSING=()

if command -v rustc &>/dev/null; then
    echo -e "${GREEN}  rustc $(rustc --version | awk '{print $2}')${NC}"
else
    echo -e "${RED}  rustc not found${NC}"
    MISSING+=(rust)
fi

if command -v cargo &>/dev/null; then
    echo -e "${GREEN}  cargo $(cargo --version | awk '{print $2}')${NC}"
else
    echo -e "${RED}  cargo not found${NC}"
    MISSING+=(cargo)
fi

if command -v node &>/dev/null; then
    echo -e "${GREEN}  node $(node --version)${NC}"
else
    echo -e "${RED}  node not found${NC}"
    MISSING+=(node)
fi

if command -v npm &>/dev/null; then
    echo -e "${GREEN}  npm $(npm --version)${NC}"
else
    echo -e "${RED}  npm not found${NC}"
    MISSING+=(npm)
fi

if command -v tmux &>/dev/null; then
    echo -e "${GREEN}  tmux $(tmux -V | awk '{print $2}')${NC}"
else
    echo -e "${YELLOW}  tmux not found (will install)${NC}"
    MISSING+=(tmux)
fi

if command -v cloudflared &>/dev/null; then
    echo -e "${GREEN}  cloudflared installed${NC}"
else
    echo -e "${YELLOW}  cloudflared not found (will install)${NC}"
    MISSING+=(cloudflared)
fi

# Install what we can via brew
if [ ${#MISSING[@]} -gt 0 ] && command -v brew &>/dev/null; then
    for dep in "${MISSING[@]}"; do
        case "$dep" in
            rust|cargo)
                echo -e "${BLUE}> Installing Rust via rustup...${NC}"
                curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
                source "$HOME/.cargo/env"
                ;;
            node|npm)
                echo -e "${BLUE}> Installing Node.js...${NC}"
                brew install node
                ;;
            tmux)
                echo -e "${BLUE}> Installing tmux...${NC}"
                brew install tmux
                ;;
            cloudflared)
                echo -e "${BLUE}> Installing cloudflared...${NC}"
                brew install cloudflared
                ;;
        esac
    done
fi

# Verify critical deps
for cmd in rustc cargo node npm; do
    if ! command -v "$cmd" &>/dev/null; then
        echo -e "${RED}Error: $cmd is required but not installed.${NC}"
        echo "  Install Rust: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
        echo "  Install Node: brew install node"
        exit 1
    fi
done

# ── Build web UI ─────────────────────────────────────────────

echo ""
echo -e "${BLUE}> Building web UI...${NC}"
cd "$PROJECT_ROOT/relay-server/web-ui"
npm install --silent 2>&1 | tail -1
npm run build 2>&1 | tail -3
echo -e "${GREEN}  Web UI built${NC}"

# ── Build relay-server ───────────────────────────────────────

echo ""
echo -e "${BLUE}> Building relay-server...${NC}"
cd "$PROJECT_ROOT/relay-server"
cargo build --release 2>&1 | grep -E "Compiling relay|Finished|error" || true
echo -e "${GREEN}  relay-server built${NC}"

# ── Build mac-client ─────────────────────────────────────────

echo ""
echo -e "${BLUE}> Building mac-client...${NC}"
cd "$PROJECT_ROOT/mac-client"
cargo build --release 2>&1 | grep -E "Compiling mac|Finished|error" || true
echo -e "${GREEN}  mac-client built${NC}"

# ── Done ─────────────────────────────────────────────────────

echo ""
echo -e "${GREEN}========================================"
echo "  Setup complete!"
echo "========================================${NC}"
echo ""
echo "  Start everything:"
echo -e "    ${BLUE}./scripts/start.sh${NC}"
echo ""
echo "  What it does:"
echo "    1. Starts relay-server (localhost:3000)"
echo "    2. Starts mac-client (menu bar icon)"
echo "    3. Starts cloudflared tunnel (public URL)"
echo "    4. Copies tunnel URL to clipboard"
echo ""
echo "  Then open the URL on your phone and enter the session code."
echo ""
