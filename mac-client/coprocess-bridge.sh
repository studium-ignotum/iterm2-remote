#!/bin/bash
# coprocess-bridge.sh - Run as iTerm2 coprocess per session
#
# Connects terminal I/O to a Unix domain socket for the Python bridge.
# iTerm2 launches this script as a coprocess for each terminal session.
#
# How iTerm2 coprocesses work:
#   - STDIN  receives raw PTY output (byte-for-byte terminal data including
#            ANSI escape sequences) from the shell running in the session
#   - STDOUT is treated as keyboard input by iTerm2, fed back into the session
#
# This script bridges stdin/stdout to a Unix domain socket so the Python
# bridge (iterm-bridge.py) can relay terminal data to the Node.js Mac client.
#
# Usage: coprocess-bridge.sh <session_id> <socket_path>
#
# Arguments:
#   session_id   - iTerm2 session identifier (for logging/debugging)
#   socket_path  - Path to Unix domain socket created by the Python bridge

set -euo pipefail

SESSION_ID="$1"
SOCKET_PATH="$2"

if [ -z "$SESSION_ID" ] || [ -z "$SOCKET_PATH" ]; then
    echo "Usage: $0 <session_id> <socket_path>" >&2
    exit 1
fi

# Wait briefly for the Python bridge to set up the socket server.
# The bridge creates the socket before launching us, but there is a
# small race window for the listen backlog to be ready.
sleep 0.1

# Retry connection a few times in case the socket isn't ready yet
MAX_RETRIES=5
RETRY_DELAY=0.2

connect_with_retry() {
    local attempt=0
    while [ $attempt -lt $MAX_RETRIES ]; do
        if [ -S "$SOCKET_PATH" ]; then
            return 0
        fi
        attempt=$((attempt + 1))
        sleep "$RETRY_DELAY"
    done
    echo "Error: socket $SOCKET_PATH not found after $MAX_RETRIES retries" >&2
    return 1
}

# Cleanup handler for temporary files
cleanup() {
    local exit_code=$?
    if [ -n "${FIFO:-}" ]; then
        rm -f "$FIFO"
    fi
    if [ -n "${NC_PID:-}" ]; then
        kill "$NC_PID" 2>/dev/null || true
    fi
    exit $exit_code
}
trap cleanup EXIT INT TERM

# Wait for socket to be available
if ! connect_with_retry; then
    exit 1
fi

# Use socat to bidirectionally connect stdin/stdout to the Unix socket.
#   - stdin (PTY output)  -> socket (Python bridge receives terminal data)
#   - socket (Python bridge sends input) -> stdout (becomes keyboard input)
#
# socat is preferred: bidirectional, handles buffering correctly, single process.
# Falls back to nc + named pipe if socat is not available.
if command -v socat &>/dev/null; then
    exec socat - "UNIX-CONNECT:${SOCKET_PATH}"
else
    # Fallback: use nc (netcat) with a named pipe for bidirectional communication.
    # This is less reliable than socat but works on stock macOS.
    if command -v nc &>/dev/null; then
        FIFO="/tmp/iterm-coprocess-fifo-$$"
        rm -f "$FIFO"
        mkfifo "$FIFO"

        # Background: read from socket via nc, write to stdout (-> iTerm2 keyboard input)
        nc -U "$SOCKET_PATH" < "$FIFO" &
        NC_PID=$!

        # Foreground: read from stdin (PTY output), write to nc via fifo (-> socket)
        cat > "$FIFO"

        # When cat exits (stdin closed), clean up nc
        kill "$NC_PID" 2>/dev/null || true
        wait "$NC_PID" 2>/dev/null || true
        rm -f "$FIFO"
    else
        echo "Error: socat or nc required for coprocess bridge" >&2
        echo "Install socat: brew install socat" >&2
        exit 1
    fi
fi
