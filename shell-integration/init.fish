# Terminal Remote - Fish Integration
# Auto-wraps shell in tmux for remote access
# Source this file in config.fish: source ~/.terminal-remote/init.fish

# Skip if already in tmux
if set -q TMUX
    exit 0
end

# Skip if not interactive
if not status is-interactive
    exit 0
end

# Generate unique session name based on terminal
function _terminal_remote_session_name
    set -l tty_name (tty 2>/dev/null | sed 's|/dev/||' | tr '/' '-')
    echo "term-$tty_name-$fish_pid"
end

function _terminal_remote_init
    set -l session_name (_terminal_remote_session_name)

    # Check if session already exists
    if tmux has-session -t "$session_name" 2>/dev/null
        # Attach to existing session
        exec tmux attach-session -t "$session_name"
    else
        # Create new session with current directory
        exec tmux new-session -s "$session_name"
    end
end

# Run tmux wrapper
_terminal_remote_init
