#!/bin/bash
set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "📦 Backing up Omarchy Linux & Hyprland Dotfiles to $DOTFILES_DIR..."

# 1. Configs
mkdir -p "$DOTFILES_DIR/configs"
for cfg in hypr omarchy foot alacritty kitty ghostty btop nvim gtk-3.0; do
    if [ -d "$HOME/.config/$cfg" ]; then
        echo "  • Backing up ~/.config/$cfg..."
        rm -rf "$DOTFILES_DIR/configs/$cfg"
        cp -r "$HOME/.config/$cfg" "$DOTFILES_DIR/configs/"
    fi
done

# Files
[ -f "$HOME/.config/starship.toml" ] && cp "$HOME/.config/starship.toml" "$DOTFILES_DIR/configs/"

# 2. Themes & Wallpapers
mkdir -p "$DOTFILES_DIR/themes"
if [ -d "$HOME/.config/omarchy/themes" ]; then
    echo "  • Backing up Omarchy themes & wallpapers..."
    cp -r "$HOME/.config/omarchy/themes/"* "$DOTFILES_DIR/themes/" 2>/dev/null || true
fi

# 3. Plugins
mkdir -p "$DOTFILES_DIR/plugins"
if [ -d "$HOME/.config/omarchy/plugins" ]; then
    echo "  • Backing up Omarchy plugins..."
    cp -r "$HOME/.config/omarchy/plugins/"* "$DOTFILES_DIR/plugins/" 2>/dev/null || true
fi

# 4. Git Push
if [ -d "$DOTFILES_DIR/.git" ]; then
    echo "🚀 Committing and pushing dotfiles to GitHub..."
    git -C "$DOTFILES_DIR" add .
    git -C "$DOTFILES_DIR" commit -m "chore(backup): Auto-sync Omarchy dotfiles and wallpapers ($(date +'%Y-%m-%d %H:%M'))" || true
    git -C "$DOTFILES_DIR" push origin main 2>/dev/null || true
fi

echo "✅ Dotfiles backup completed successfully!"
