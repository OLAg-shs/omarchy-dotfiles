#!/bin/bash
set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "🚀 Restoring Omarchy Linux & Hyprland Dotfiles from $DOTFILES_DIR..."

# 1. Restore Configs
mkdir -p "$HOME/.config"
for cfg in "$DOTFILES_DIR/configs/"*; do
    if [ -e "$cfg" ]; then
        name=$(basename "$cfg")
        echo "  • Restoring $name to ~/.config/$name..."
        rm -rf "$HOME/.config/$name"
        cp -r "$cfg" "$HOME/.config/"
    fi
done

# 2. Restore Themes
if [ -d "$DOTFILES_DIR/themes" ]; then
    mkdir -p "$HOME/.config/omarchy/themes"
    echo "  • Restoring themes to ~/.config/omarchy/themes..."
    cp -r "$DOTFILES_DIR/themes/"* "$HOME/.config/omarchy/themes/" 2>/dev/null || true
fi

# 3. Restore Plugins
if [ -d "$DOTFILES_DIR/plugins" ]; then
    mkdir -p "$HOME/.config/omarchy/plugins"
    echo "  • Restoring plugins to ~/.config/omarchy/plugins..."
    cp -r "$DOTFILES_DIR/plugins/"* "$HOME/.config/omarchy/plugins/" 2>/dev/null || true
fi

echo "🔄 Restarting Omarchy Shell..."
omarchy restart shell 2>/dev/null || true

echo "🎉 Omarchy desktop environment restored successfully!"
