#!/bin/bash

MODE=${1:-host}
HOST_IP="192.168.0.145"
PORT_SEND=4567   # Host listens here for vm clipboard changes
PORT_BROADCAST=4568 # Host broadcasts clipboard to all VMs

TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

case "$MODE" in
  host)
    # Watch host clipboard and broadcast it
    (
      LAST_HASH=""
      while true; do
        TEMP_FILE="$TMP_DIR/clip.dat"
        wl-paste --no-newline > "$TEMP_FILE" 2>/dev/null || continue
        NEW_HASH=$(sha256sum "$TEMP_FILE" | cut -d ' ' -f1)
        if [[ "$NEW_HASH" != "$LAST_HASH" ]]; then
          cat "$TEMP_FILE" | socat -u - TCP4-LISTEN:$PORT_BROADCAST,reuseaddr,fork &
          LAST_HASH="$NEW_HASH"
        fi
        sleep 0.3
      done
    ) &

    # Accept clipboard input from VMs and apply it to host
    socat -u TCP4-LISTEN:$PORT_SEND,reuseaddr,fork SYSTEM:'wl-copy'
    ;;

  vm)
    # Send clipboard changes from VM to host
    (
      LAST_HASH=""
      while true; do
        TEMP_FILE="$TMP_DIR/clip.dat"
        wl-paste --no-newline > "$TEMP_FILE" 2>/dev/null || continue
        NEW_HASH=$(sha256sum "$TEMP_FILE" | cut -d ' ' -f1)
        if [[ "$NEW_HASH" != "$LAST_HASH" ]]; then
          socat -u "OPEN:$TEMP_FILE,rdonly" TCP:$HOST_IP:$PORT_SEND
          LAST_HASH="$NEW_HASH"
        fi
        sleep 0.3
      done
    ) &

    # Receive clipboard updates from host
    socat -u TCP:$HOST_IP:$PORT_BROADCAST SYSTEM:'wl-copy'
    ;;
esac

