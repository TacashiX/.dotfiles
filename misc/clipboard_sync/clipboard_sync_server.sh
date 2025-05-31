#!/bin/bash

# Config
REMOTE_IP="$1"         # IP of the peer (e.g., 192.168.122.2)
LOCAL_PORT="$2"        # Port to listen on
REMOTE_PORT="$3"       # Port to send to

# Init last hash
LAST_HASH=""

# Watch clipboard and send if new
watch_clipboard() {
  wl-paste --watch --progress --foreground --type text/plain,image/png --watch-cmd - | \
  while IFS= read -r line || [[ -n "$line" ]]; do
    TEMP_FILE=$(mktemp)
    wl-paste --type text/plain,image/png > "$TEMP_FILE"

    NEW_HASH=$(sha256sum "$TEMP_FILE" | cut -d ' ' -f1)

    if [[ "$NEW_HASH" != "$LAST_HASH" ]]; then
      socat -u "OPEN:$TEMP_FILE,rdonly" TCP:$REMOTE_IP:$REMOTE_PORT
      LAST_HASH="$NEW_HASH"
    fi

    rm "$TEMP_FILE"
  done
}

# Receive incoming clipboard data and apply
receive_clipboard() {
  socat -u TCP-LISTEN:$LOCAL_PORT,reuseaddr,fork SYSTEM:'wl-copy --type text/plain,image/png'
}

# Start both in parallel
watch_clipboard &
receive_clipboard

