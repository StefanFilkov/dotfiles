#!/bin/bash

# 1. Install standard packages
echo "Installing packages..."

sudo pacman -S --needed - < pkglist.txt
# 2. Install AUR helper (yay) if not present
if ! command -v yay &> /dev/null; then
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si
    cd ..
    rm -rf yay
fi

# 3. Install AUR packages
yay -S --needed brave-bin hyprshot wlogout

# 4. Link config files using Stow
echo "Stowing dotfiles..."
stow hypr
stow waybar
stow rofi

echo "Done! Restart Hyprland."
