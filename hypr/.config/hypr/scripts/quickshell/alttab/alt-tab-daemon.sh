#!/usr/bin/env bash
# Alt-tab switcher daemon: maintains an MRU list of window addresses and
# captures thumbnails of focused windows via grim.

set -u

STATE_DIR="/tmp/alt-tab-switcher"
THUMB_DIR="$STATE_DIR/thumbs"
MRU_FILE="$STATE_DIR/mru"
LOCK_FILE="$STATE_DIR/.mru.lock"

mkdir -p "$THUMB_DIR"
touch "$MRU_FILE" "$LOCK_FILE"

if [[ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    echo "alt-tab-daemon: HYPRLAND_INSTANCE_SIGNATURE not set; aborting." >&2
    exit 1
fi

EVENT_SOCK="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr/${HYPRLAND_INSTANCE_SIGNATURE}/.socket2.sock"

mru_push() {
    local addr="$1"
    [[ -z "$addr" || "$addr" == "0x0" ]] && return
    (
        flock -x 9
        local tmp
        tmp=$(mktemp)
        {
            echo "$addr"
            grep -vxF "$addr" "$MRU_FILE" 2>/dev/null || true
        } > "$tmp"
        mv "$tmp" "$MRU_FILE"
    ) 9>"$LOCK_FILE"
}

mru_remove() {
    local addr="$1"
    [[ -z "$addr" ]] && return
    (
        flock -x 9
        local tmp
        tmp=$(mktemp)
        grep -vxF "$addr" "$MRU_FILE" > "$tmp" 2>/dev/null || true
        mv "$tmp" "$MRU_FILE"
    ) 9>"$LOCK_FILE"
    rm -f "$THUMB_DIR/$addr.png"
}

capture_window() {
    local addr="$1"
    [[ -z "$addr" || "$addr" == "0x0" ]] && return
    local geom
    geom=$(hyprctl clients -j 2>/dev/null | jq -r --arg a "$addr" \
        '.[] | select(.address == $a) | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')
    [[ -z "$geom" || "$geom" == *"null"* ]] && return
    local x y wh w h
    x="${geom%%,*}"
    rest="${geom#*,}"
    y="${rest%% *}"
    wh="${rest#* }"
    w="${wh%x*}"
    h="${wh#*x}"
    if (( w < 50 || h < 50 )); then return; fi
    grim -g "$geom" -s 0.4 "$THUMB_DIR/$addr.png" >/dev/null 2>&1 || true
}

# Bootstrap: seed MRU with the currently focused window
seed() {
    local active
    active=$(hyprctl activewindow -j 2>/dev/null | jq -r '.address // empty')
    [[ -n "$active" ]] && mru_push "$active"
    # Add other clients to the back so they appear in the list
    while IFS= read -r addr; do
        [[ -n "$addr" && "$addr" != "$active" ]] || continue
        # append to end of MRU file (older history)
        if ! grep -qxF "$addr" "$MRU_FILE"; then
            (flock -x 9; echo "$addr" >> "$MRU_FILE") 9>"$LOCK_FILE"
        fi
    done < <(hyprctl clients -j 2>/dev/null | jq -r '.[].address')
    [[ -n "$active" ]] && capture_window "$active" &
}

seed

# Coalesced background capture: if many activewindow events fire, skip ahead
LAST_FOCUS_ADDR=""
CAPTURE_PID=0

# Stream events. socat keeps the connection alive.
while IFS= read -r line; do
    event="${line%%>>*}"
    payload="${line#*>>}"

    case "$event" in
        activewindowv2)
            # payload is a hex address without 0x prefix
            [[ -z "$payload" ]] && continue
            addr="0x$payload"
            mru_push "$addr"
            LAST_FOCUS_ADDR="$addr"

            # Debounced capture: kill any pending capture, schedule a new one
            if (( CAPTURE_PID > 0 )) && kill -0 "$CAPTURE_PID" 2>/dev/null; then
                kill "$CAPTURE_PID" 2>/dev/null || true
            fi
            (
                sleep 0.35
                # Only capture if this is still the latest focused address
                if [[ "$(cat "$STATE_DIR/.last_focus" 2>/dev/null)" == "$addr" ]]; then
                    capture_window "$addr"
                fi
            ) &
            CAPTURE_PID=$!
            echo "$addr" > "$STATE_DIR/.last_focus"
            ;;
        closewindow)
            # payload is an address without 0x
            [[ -z "$payload" ]] && continue
            mru_remove "0x$payload"
            ;;
        openwindow)
            # payload: ADDR,WORKSPACENAME,CLASS,TITLE
            addr="0x${payload%%,*}"
            (
                flock -x 9
                if ! grep -qxF "$addr" "$MRU_FILE"; then
                    echo "$addr" >> "$MRU_FILE"
                fi
            ) 9>"$LOCK_FILE"
            ;;
    esac
done < <(socat -U - "UNIX-CONNECT:$EVENT_SOCK")
