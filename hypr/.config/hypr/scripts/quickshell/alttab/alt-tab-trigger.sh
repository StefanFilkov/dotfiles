#!/usr/bin/env bash
# Invoked by the Alt+Tab keybind. Refreshes the switcher's view-state and
# bumps a counter that the QML window watches. Each press = one bump:
# the QML opens on the first bump and cycles MRU on each subsequent bump
# while it is open.

set -u

STATE_DIR="/tmp/alt-tab-switcher"
STATE_FILE="$STATE_DIR/state.json"
PRESS_FILE="$STATE_DIR/press"
THUMB_DIR="$STATE_DIR/thumbs"
MRU_FILE="$STATE_DIR/mru"

mkdir -p "$THUMB_DIR"
touch "$MRU_FILE"

# Bump a fresh thumbnail of the currently-focused window before we open,
# so the snapshot the user sees is up to date.
ACTIVE=$(hyprctl activewindow -j 2>/dev/null | jq -r '.address // empty')
if [[ -n "$ACTIVE" ]]; then
    GEOM=$(hyprctl activewindow -j 2>/dev/null | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')
    if [[ -n "$GEOM" && "$GEOM" != *"null"* ]]; then
        grim -g "$GEOM" -s 0.4 "$THUMB_DIR/$ACTIVE.png" >/dev/null 2>&1 || true
    fi
fi

# Build state.json
CLIENTS=$(hyprctl clients -j 2>/dev/null)
WORKSPACES=$(hyprctl workspaces -j 2>/dev/null)
MONITORS=$(hyprctl monitors -j 2>/dev/null)
MRU_JSON=$(jq -R . "$MRU_FILE" 2>/dev/null | jq -s . || echo "[]")
ACTIVE_JSON=$(printf '%s' "$ACTIVE" | jq -R .)

TMP=$(mktemp)
jq -n \
    --argjson clients "$CLIENTS" \
    --argjson workspaces "$WORKSPACES" \
    --argjson monitors "$MONITORS" \
    --argjson mru "$MRU_JSON" \
    --argjson active "$ACTIVE_JSON" \
    --arg thumbDir "$THUMB_DIR" \
    '{
        clients: $clients,
        workspaces: $workspaces,
        monitors: $monitors,
        mru: ($mru | map(select(. != ""))),
        active: $active,
        thumbDir: $thumbDir
    }' > "$TMP" && mv "$TMP" "$STATE_FILE"

DIR="${1:-next}"
case "$DIR" in
    prev|backward|back) DIR="prev" ;;
    *) DIR="next" ;;
esac

# Atomically increment the press counter. The QML watches this file.
# Format: "<seq> <direction>"
(
    flock -x 9
    n=$(awk '{print $1}' "$PRESS_FILE" 2>/dev/null || echo 0)
    n=$(( n + 1 ))
    printf '%s %s\n' "$n" "$DIR" > "$PRESS_FILE"
) 9>"$STATE_DIR/.press.lock"
