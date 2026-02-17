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
stow fish
stow kitty
# 5. Fish & Fisher Setup
echo "Setting up Fish..."
# We run this command INSIDE fish using the -c flag
fish -c 'curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher nickeb96/puffer-fish'

# Run the installer script
# Note: This clones into /usr/share/sddm/themes and edits /etc/sddm.conf
if [ ! -d "/usr/share/sddm/themes/sddm-astronaut-theme" ]; then
    echo "Installing Astronaut Theme..."
    # We pipe to bash. The script usually handles sudo internally or asks for it.
    bash -c "$(curl -fsSL https://raw.githubusercontent.com/keyitdev/sddm-astronaut-theme/master/setup.sh)"
fi

# change default shell to fish
sudo usermod -s /usr/bin/fish $USER

echo "Done! Restart Hyprland."
