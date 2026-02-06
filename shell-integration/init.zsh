# Terminal Remote - Zsh Integration
# Auto-wraps shell in tmux for remote access
# Source this file in .zshrc: source ~/.terminal-remote/init.zsh

# Skip if already in tmux
[[ -n "$TMUX" ]] && return

# Skip if not interactive
[[ ! -o interactive ]] && return

# Generate unique session name based on terminal
_terminal_remote_session_name() {
  local tty_name="${TTY##*/}"
  local window_id="${TERM_SESSION_ID:-$WINDOWID}"

  # Use TTY + timestamp for uniqueness
  if [[ -n "$window_id" ]]; then
    echo "term-${tty_name}-${window_id##*:}"
  else
    echo "term-${tty_name}-$$"
  fi
}

_terminal_remote_init() {
  local session_name
  session_name=$(_terminal_remote_session_name)

  # Check if session already exists
  if tmux has-session -t "$session_name" 2>/dev/null; then
    # Attach to existing session
    exec tmux attach-session -t "$session_name"
  else
    # Create new session with current directory
    exec tmux new-session -s "$session_name"
  fi
}

# Run tmux wrapper
_terminal_remote_init
