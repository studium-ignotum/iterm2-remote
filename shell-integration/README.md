# Terminal Remote Shell Integration

Shell integration scripts that connect your terminal sessions to the mac-client for remote access. Once installed, every new shell session automatically registers with Terminal Remote, enabling you to control any terminal from anywhere.

## Installation

1. Run the installer:

```bash
cd shell-integration && ./install.sh
```

2. Add the source line to your shell configuration (see below).

3. Open a new terminal to activate.

## Shell Configuration

Add one of these lines to the **end** of your shell's rc file:

### Zsh (~/.zshrc)

```bash
source ~/.terminal-remote/init.zsh
```

### Bash (~/.bashrc)

```bash
source ~/.terminal-remote/init.bash
```

### Fish (~/.config/fish/config.fish)

```fish
source ~/.terminal-remote/init.fish
```

## Features

- **Auto-connect on shell startup** - Sessions register automatically when you open a terminal
- **Session name from current directory** - Each session shows as "dirname [PID]" for easy identification
- **Live directory tracking** - Session name updates in real-time when you change directories
- **Disconnect warning** - Shows "Terminal Remote disconnected" if mac-client stops
- **Auto-reconnect** - Automatically reconnects when mac-client restarts
- **Graceful exit** - Clean disconnection when you close the shell

## Important Notes

- **Source at the END of your rc file** - After oh-my-zsh, starship, powerlevel10k, or other prompt customizations
- **Requires mac-client running** - Sessions only appear when mac-client is active
- **Works with any terminal app** - iTerm2, Terminal.app, Alacritty, Warp, Kitty, etc.
- **Shows "Terminal Remote not running"** - Normal message when mac-client isn't started yet
- **No perceptible delay** - Socket check is instant, connection happens in background

## Troubleshooting

### "Terminal Remote not running"

This is normal - it means mac-client isn't currently running. Start mac-client and open a new terminal, or press Enter in an existing terminal to auto-reconnect.

### "Terminal Remote disconnected"

mac-client quit or crashed. Start mac-client again and press Enter to reconnect.

### Verify socket exists

```bash
ls -la /tmp/terminal-remote.sock
```

If the socket doesn't exist, mac-client isn't running.

### Verify installation

```bash
ls ~/.terminal-remote/
```

Should show: `init.zsh`, `init.bash`, `init.fish`

### Prompt looks wrong or shows errors

Make sure the source line is at the **end** of your rc file, after all other prompt customizations. The shell integration uses standard hooks (add-zsh-hook, PROMPT_COMMAND, fish events) and should not conflict with prompt themes.

### Session not appearing in mac-client

1. Verify mac-client is running (check menu bar icon)
2. Open a **new** terminal (existing shells won't have the integration until restarted)
3. Check for error messages when the shell starts
