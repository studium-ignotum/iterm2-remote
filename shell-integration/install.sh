#!/bin/bash
# Terminal Remote Shell Integration Installer
# Installs init scripts to ~/.terminal-remote/

set -e

INSTALL_DIR="$HOME/.terminal-remote"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Installing Terminal Remote shell integration..."

# Create installation directory
mkdir -p "$INSTALL_DIR"

# Copy init scripts
cp "$SCRIPT_DIR/init.zsh" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/init.bash" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/init.fish" "$INSTALL_DIR/"

echo "Installed to $INSTALL_DIR/"
echo ""
echo "Add to your shell configuration:"
echo ""
echo "  Zsh (~/.zshrc):"
echo "    source ~/.terminal-remote/init.zsh"
echo ""
echo "  Bash (~/.bashrc):"
echo "    source ~/.terminal-remote/init.bash"
echo ""
echo "  Fish (~/.config/fish/config.fish):"
echo "    source ~/.terminal-remote/init.fish"
echo ""
echo "Note: Add the source line at the END of your rc file"
echo "      (after oh-my-zsh, starship, or other prompt tools)"
