#!/bin/bash

# Arguments
REMOTE_IP="$1"
LOCAL_PORT="$2"
REMOTE_PORT="$3"

# Dependencies check
for cmd in wl-paste wl-copy socat sha256sum; do
    command -v "$cmd" >/dev/null || {
        echo "Missing dependency: $cmd"
        exit 1
    }
done

# Temp files
LAST_HASH=""
TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

# Watch clipboard loop
watch_clipboard() {
    while true; do
        TEMP_FILE="$TMP_DIR/clip.dat"

        # Dump clipboard to temp file
        wl-paste --no-newline > "$TEMP_FILE" 2>/dev/null || continue
        NEW_HASH=$(sha256sum "$TEMP_FILE" | cut -d ' ' -f1)

        if [[ "$NEW_HASH" != "$LAST_HASH" ]]; then
            socat -u "OPEN:$TEMP_FILE,rdonly" TCP:$REMOTE_IP:$REMOTE_PORT
            LAST_HASH="$NEW_HASH"
        fi

        sleep 0.3
    done
}

# Clipboard receiver
receive_clipboard() {
    socat -u TCP-LISTEN:$LOCAL_PORT,reuseaddr,fork SYSTEM:'wl-copy'
}

# Run both in parallel
watch_clipboard &
receive_clipboard

