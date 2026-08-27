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

# Systemd User Services
mkdir -p "$DOTFILES_DIR/configs/systemd/user"
if [ -d "$HOME/.config/systemd/user" ]; then
    echo "  • Backing up systemd user services & timers..."
    cp -r "$HOME/.config/systemd/user/"* "$DOTFILES_DIR/configs/systemd/user/" 2>/dev/null || true
fi

# Files
[ -f "$HOME/.config/starship.toml" ] && cp "$HOME/.config/starship.toml" "$DOTFILES_DIR/configs/"

# 2. Custom Scripts & Binaries
mkdir -p "$DOTFILES_DIR/bin"
for bin_file in omarchy-storage-cleaner omarchy-turbo omarchy-turbo-gui omarchy-theme-cycle playerctl; do
    if [ -f "$HOME/.local/bin/$bin_file" ]; then
        echo "  • Backing up ~/.local/bin/$bin_file..."
        cp "$HOME/.local/bin/$bin_file" "$DOTFILES_DIR/bin/"
    fi
done

# 3. Themes & Wallpapers
mkdir -p "$DOTFILES_DIR/themes"
if [ -d "$HOME/.config/omarchy/themes" ]; then
    echo "  • Backing up Omarchy themes & wallpapers..."
    cp -r "$HOME/.config/omarchy/themes/"* "$DOTFILES_DIR/themes/" 2>/dev/null || true
fi

# 4. Plugins
mkdir -p "$DOTFILES_DIR/plugins"
if [ -d "$HOME/.config/omarchy/plugins" ]; then
    echo "  • Backing up Omarchy plugins..."
    cp -r "$HOME/.config/omarchy/plugins/"* "$DOTFILES_DIR/plugins/" 2>/dev/null || true
fi

# 5. Git Push
if [ -d "$DOTFILES_DIR/.git" ]; then
    echo "🚀 Committing and pushing dotfiles to GitHub..."
    git -C "$DOTFILES_DIR" add .
    git -C "$DOTFILES_DIR" commit -m "chore(backup): Auto-sync Omarchy dotfiles, plugins, scripts & systemd ($(date +'%Y-%m-%d %H:%M'))" || true
    git -C "$DOTFILES_DIR" push origin main 2>/dev/null || true
fi

echo "✅ Dotfiles backup completed successfully!"
