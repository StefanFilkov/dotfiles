#!/bin/bash
# Build + install waynaptics as a pacman package (clean rollback via `pacman -Rns waynaptics`).
# Run as your normal user (NOT root). makepkg invokes sudo only for the final pacman step.
set -euo pipefail
cd "$(dirname "$0")"

echo "==> Building waynaptics package with makepkg..."
makepkg -sif

echo
echo "==> Installed. The systemd service is enabled + started (see messages above)."
echo "    GUI config:  waynaptics-config"
echo "    Disable:     sudo systemctl disable --now waynaptics"
echo "    Remove:      sudo pacman -Rns waynaptics"
