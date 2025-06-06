#!/bin/bash
set -e

MODE=${1:-host}
HOST_IP="192.168.0.145"
PORT_SEND=4567   # Host listens here for vm clipboard changes
PORT_BROADCAST=4568 # Host broadcasts clipboard to all VMs

TMP_DIR=$(mktemp -d)
FIFO="$TMP_DIR/fifo"
mkdir -p "$TMP_DIR"

PIDS=()

cleanup() {
  echo "Cleaning up..."
  for pid in "${PIDS[@]}"; do
    kill "$pid" 2>/dev/null || true
  done
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT INT TERM

case "$MODE" in
  host)
    mkfifo "$FIFO"

    # Broadcast clipboard changes to all connected VMs
    socat -u OPEN:"$FIFO",rdonly TCP4-LISTEN:$PORT_BROADCAST,reuseaddr,fork &
    PIDS+=($!)

    # Watch clipboard and write to FIFO
    (
      LAST_HASH=""
      while true; do
        TEMP_FILE="$TMP_DIR/clip.dat"
        wl-paste --no-newline > "$TEMP_FILE" 2>/dev/null || continue
        NEW_HASH=$(sha256sum "$TEMP_FILE" | cut -d ' ' -f1)
        if [[ "$NEW_HASH" != "$LAST_HASH" ]]; then
          cat "$TEMP_FILE" > "$FIFO"
          LAST_HASH="$NEW_HASH"
        fi
        sleep 0.3
      done
    ) &
    PIDS+=($!)

    # Accept clipboard input from VMs and apply it to host
    socat -u TCP4-LISTEN:$PORT_SEND,reuseaddr,fork SYSTEM:'wl-copy' &
    PIDS+=($!)

    wait
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
    PIDS+=($!)

    # Receive clipboard updates from host
    socat -u TCP:$HOST_IP:$PORT_BROADCAST SYSTEM:'wl-copy' &
    PIDS+=($!)

    wait
    ;;
esac

