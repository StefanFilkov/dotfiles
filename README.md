# Fresh Dotfiles

Configuration files for Hyprland, Waybar, Rofi, and standard Arch tools. Managed with [GNU Stow](https://www.gnu.org/software/stow/).

## 1. Fresh Install (Recovery)

Run these commands on a fresh Arch Linux installation to restore everything.

```bash
# 1. Install git and stow
sudo pacman -S git stow

# 2. Clone this repo
git clone [https://github.com/StefanFilkov/dotfiles.git](https://github.com/StefanFilkov/dotfiles.git) ~/dotfiles
cd ~/dotfiles

# 3. Run the setup script (installs packages + links configs)
chmod +x install.sh
./install.sh
```
---

## 2. Daily Maintenance
**How to add a NEW config file**
If you configure a new app (e.g., kitty), do not leave the config in ~/.config. Move it here!

1. Create folder: mkdir -p ~/dotfiles/kitty/.config/kitty

2. Move config: mv ~/.config/kitty/kitty.conf ~/dotfiles/kitty/.config/kitty/

3. Link it: cd ~/dotfiles && stow kitty

How to add a NEW package
When you install something new (e.g., sudo pacman -S vlc), don't forget to add it to your backup list.
Just edit the install.sh file and add the package name to the pacman -S command.

