#!/bin/bash

# 1. Define where your wallpapers are stored
DIR="$HOME/Pictures/wallpaper"

# 2. Find a random image
RANDOM_PIC=$(find "$DIR" -type f \( -name "*.jpg" -o -name "*.png" -o -name "*.jpeg" \) | shuf -n 1)

# 3. Apply it instantly (hyprpaper now handles RAM loading/unloading automatically!)
hyprctl hyprpaper wallpaper ",$RANDOM_PIC"