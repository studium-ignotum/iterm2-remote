#!/bin/bash
set -e

echo "Building relay server..."
cd "$(dirname "$0")"
cargo build --release 2>&1 | tail -3

echo "Starting server..."
./target/release/relay-server &
SERVER_PID=$!
sleep 2

cleanup() {
    echo "Stopping server..."
    kill $SERVER_PID 2>/dev/null || true
}
trap cleanup EXIT

echo ""
echo "=== Test 1: Mac-client registration ==="
RESPONSE=$(echo '{"type":"register","client_id":"test"}' | websocat -n1 ws://localhost:3000/ws 2>/dev/null)
echo "Response: $RESPONSE"

if echo "$RESPONSE" | grep -q '"type":"registered"'; then
    echo "PASS: Mac-client registration works"
else
    echo "FAIL: Mac-client registration failed"
    exit 1
fi

echo ""
echo "=== Test 2: Browser auth with invalid code (no session) ==="
RESPONSE=$(echo '{"type":"auth","session_code":"BADCODE"}' | websocat -n1 ws://localhost:3000/ws 2>/dev/null)
echo "Response: $RESPONSE"

if echo "$RESPONSE" | grep -q '"type":"auth_failed"'; then
    echo "PASS: Invalid code rejected"
else
    echo "FAIL: Invalid code not rejected"
    exit 1
fi

echo ""
echo "=== Test 3: Invalid JSON handling ==="
RESPONSE=$(echo 'not json at all' | websocat -n1 ws://localhost:3000/ws 2>/dev/null)
echo "Response: $RESPONSE"

if echo "$RESPONSE" | grep -q '"type":"error"'; then
    echo "PASS: Invalid JSON rejected"
else
    echo "FAIL: Invalid JSON not rejected"
    exit 1
fi

echo ""
echo "=== Test 4: Browser auth with valid code (long-lived connection) ==="
# Start a mac-client that stays connected (reads from a fifo)
FIFO=$(mktemp -u)
mkfifo "$FIFO"

# Connect mac-client in background, keep alive via fifo
(echo '{"type":"register","client_id":"persistent"}'; sleep 5) | websocat ws://localhost:3000/ws > "$FIFO" 2>/dev/null &
MAC_CLIENT_PID=$!
sleep 0.5

# Read the session code from mac-client response
CODE=$(head -n1 "$FIFO" | grep -o '"code":"[^"]*"' | cut -d'"' -f4)
echo "Session code from persistent client: $CODE"

if [ -n "$CODE" ]; then
    # Now try browser auth while mac-client is still connected
    RESPONSE=$(echo "{\"type\":\"auth\",\"session_code\":\"$CODE\"}" | websocat -n1 ws://localhost:3000/ws 2>/dev/null)
    echo "Browser response: $RESPONSE"

    if echo "$RESPONSE" | grep -q '"type":"auth_success"'; then
        echo "PASS: Browser auth with valid code works"
    else
        echo "FAIL: Browser auth with valid code failed"
        kill $MAC_CLIENT_PID 2>/dev/null || true
        rm -f "$FIFO"
        exit 1
    fi
else
    echo "FAIL: Could not get session code"
    kill $MAC_CLIENT_PID 2>/dev/null || true
    rm -f "$FIFO"
    exit 1
fi

# Cleanup mac-client
kill $MAC_CLIENT_PID 2>/dev/null || true
rm -f "$FIFO"

echo ""
echo "================================"
echo "All tests passed!"
echo "================================"
