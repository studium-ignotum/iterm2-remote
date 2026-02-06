# Terminal Remote - Bash Integration
# Auto-wraps shell in tmux for remote access
# Source this file in .bashrc: source ~/.terminal-remote/init.bash

# Skip if already in tmux
[[ -n "$TMUX" ]] && return

# Skip if not interactive
[[ $- != *i* ]] && return

# Generate unique session name based on terminal
_terminal_remote_session_name() {
  local tty_name
  tty_name=$(tty 2>/dev/null | sed 's|/dev/||' | tr '/' '-')

  # Use TTY + PID for uniqueness
  echo "term-${tty_name:-$$}"
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
