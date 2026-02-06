# Terminal Remote - Zsh Integration
# Connects shell sessions to mac-client for remote access
# Source this file in .zshrc: source ~/.terminal-remote/init.zsh

# Configuration
typeset -g _TERMINAL_REMOTE_SOCKET="/tmp/terminal-remote.sock"
typeset -g _TERMINAL_REMOTE_CONNECTED=0
typeset -g _TERMINAL_REMOTE_BG_PID=""
typeset -g _TERMINAL_REMOTE_WATCHER_PID=""
typeset -g _TERMINAL_REMOTE_WARNED=0
typeset -g _TERMINAL_REMOTE_FIFO=""

# Load zsh hook system
autoload -Uz add-zsh-hook

# Generate session name: "dirname [PID]"
_terminal_remote_session_name() {
  echo "${PWD##*/} [$$]"
}

# Escape string for JSON (backslash, quote, newline, tab)
_terminal_remote_json_escape() {
  local str="$1"
  str="${str//\\/\\\\}"    # Escape backslashes first
  str="${str//\"/\\\"}"    # Escape quotes
  str="${str//$'\n'/\\n}"  # Escape newlines
  str="${str//$'\t'/\\t}"  # Escape tabs
  echo "$str"
}

# Attempt to connect to Terminal Remote
_terminal_remote_connect() {
  local name
  name=$(_terminal_remote_json_escape "$(_terminal_remote_session_name)")
  local msg="{\"name\":\"${name}\",\"shell\":\"zsh\",\"pid\":$$}"

  # Create a FIFO for sending additional messages through the connection
  _TERMINAL_REMOTE_FIFO="/tmp/terminal-remote-fifo-$$"
  rm -f "$_TERMINAL_REMOTE_FIFO"
  mkfifo "$_TERMINAL_REMOTE_FIFO" 2>/dev/null || return 1

  # Background process: send registration, then read from FIFO for additional messages
  # The FIFO stays open for writing as long as something has it open for read
  {
    echo "$msg"
    cat "$_TERMINAL_REMOTE_FIFO"  # Read from FIFO, blocks until EOF
  } | nc -U "$_TERMINAL_REMOTE_SOCKET" 2>/dev/null &!
  _TERMINAL_REMOTE_BG_PID=$!

  # Give it a moment to connect
  sleep 0.05

  # Check if it's still running (successful connection)
  if kill -0 "$_TERMINAL_REMOTE_BG_PID" 2>/dev/null; then
    _TERMINAL_REMOTE_CONNECTED=1
    _TERMINAL_REMOTE_WARNED=0
  else
    _TERMINAL_REMOTE_CONNECTED=0
    _TERMINAL_REMOTE_BG_PID=""
    rm -f "$_TERMINAL_REMOTE_FIFO"
    _TERMINAL_REMOTE_FIFO=""
  fi
}

# Send directory rename update through existing connection
_terminal_remote_send_update() {
  # Only send if we have an active FIFO
  [[ -p "$_TERMINAL_REMOTE_FIFO" ]] || return 0

  local name
  name=$(_terminal_remote_json_escape "$(_terminal_remote_session_name)")
  local msg="{\"type\":\"rename\",\"name\":\"${name}\"}"

  # Write to FIFO (goes through existing connection)
  echo "$msg" >> "$_TERMINAL_REMOTE_FIFO" 2>/dev/null
}

# Directory change hook
_terminal_remote_chpwd() {
  (( _TERMINAL_REMOTE_CONNECTED )) || return
  # Fire-and-forget: don't wait for response
  _terminal_remote_send_update
}

# Check if connection is still alive (called in precmd)
_terminal_remote_check_connection() {
  if (( _TERMINAL_REMOTE_CONNECTED )) && [[ -n "$_TERMINAL_REMOTE_BG_PID" ]]; then
    if ! kill -0 "$_TERMINAL_REMOTE_BG_PID" 2>/dev/null; then
      _TERMINAL_REMOTE_CONNECTED=0
      _TERMINAL_REMOTE_BG_PID=""
      if (( ! _TERMINAL_REMOTE_WARNED )); then
        echo "Terminal Remote disconnected"
        _TERMINAL_REMOTE_WARNED=1
      fi
      _terminal_remote_start_watcher
    fi
  fi

  # Also try to reconnect if socket appeared and we're not connected
  if (( ! _TERMINAL_REMOTE_CONNECTED )) && [[ -S "$_TERMINAL_REMOTE_SOCKET" ]]; then
    _terminal_remote_connect
    if (( _TERMINAL_REMOTE_CONNECTED )); then
      echo "Connected to Terminal Remote"
    fi
  fi
}

# Background watcher for auto-reconnect when mac-client starts
_terminal_remote_start_watcher() {
  # Already watching?
  [[ -n "$_TERMINAL_REMOTE_WATCHER_PID" ]] && kill -0 "$_TERMINAL_REMOTE_WATCHER_PID" 2>/dev/null && return

  {
    while true; do
      sleep 5
      # Check if socket appeared
      if [[ -S "$_TERMINAL_REMOTE_SOCKET" ]]; then
        # Socket exists, watcher can stop - precmd will handle reconnection
        break
      fi
    done
  } &!
  _TERMINAL_REMOTE_WATCHER_PID=$!
}

# Stop watcher if running
_terminal_remote_stop_watcher() {
  if [[ -n "$_TERMINAL_REMOTE_WATCHER_PID" ]]; then
    kill "$_TERMINAL_REMOTE_WATCHER_PID" 2>/dev/null
    _TERMINAL_REMOTE_WATCHER_PID=""
  fi
}

# Cleanup on shell exit
_terminal_remote_zshexit() {
  # Kill background process holding socket
  [[ -n "$_TERMINAL_REMOTE_BG_PID" ]] && kill "$_TERMINAL_REMOTE_BG_PID" 2>/dev/null
  # Kill watcher
  [[ -n "$_TERMINAL_REMOTE_WATCHER_PID" ]] && kill "$_TERMINAL_REMOTE_WATCHER_PID" 2>/dev/null
  # Remove FIFO
  [[ -n "$_TERMINAL_REMOTE_FIFO" ]] && rm -f "$_TERMINAL_REMOTE_FIFO"
}

# Initialize connection on script load
_terminal_remote_init() {
  # Fast check: socket file exists?
  if [[ ! -S "$_TERMINAL_REMOTE_SOCKET" ]]; then
    echo "Terminal Remote not running"
    _terminal_remote_start_watcher
    return 0
  fi

  _terminal_remote_connect
  if (( _TERMINAL_REMOTE_CONNECTED )); then
    echo "Connected to Terminal Remote"
  else
    echo "Terminal Remote not running"
    _terminal_remote_start_watcher
  fi
}

# Register hooks
add-zsh-hook chpwd _terminal_remote_chpwd
add-zsh-hook precmd _terminal_remote_check_connection

# Register exit handler (use trap for compatibility)
trap '_terminal_remote_zshexit' EXIT

# Auto-initialize when sourced
_terminal_remote_init
