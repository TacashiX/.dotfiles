#!/bin/bash
set -e

# Configuration
MODE=${1:-host}
HOST_IP=${HOST_IP:-"192.168.0.145"}  # Can be overridden by env var
PORT_SEND=${PORT_SEND:-4567}         # Host listens for VM clipboard changes
PORT_BROADCAST=${PORT_BROADCAST:-4568}  # Host broadcasts to VMs
LOCK_FILE="/tmp/clipboard-sync.lock"
TIMEOUT=5  # Timeout for socat connections

# Ensure dependencies are installed
command -v wl-copy >/dev/null 2>&1 || { echo "wl-copy required"; exit 1; }
command -v wl-paste >/dev/null 2>&1 || { echo "wl-paste required"; exit 1; }
command -v socat >/dev/null 2>&1 || { echo "socat required"; exit 1; }

# Temporary directory and FIFO
TMP_DIR=$(mktemp -d)
FIFO="$TMP_DIR/fifo"
mkdir -p "$TMP_DIR"

PIDS=()

# Logging function
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $MODE: $1"
}

# Cleanup function
cleanup() {
  log "Cleaning up..."
  for pid in "${PIDS[@]}"; do
    kill "$pid" 2>/dev/null || true
  done
  rm -rf "$TMP_DIR"
  rm -f "$LOCK_FILE"
}
trap cleanup EXIT INT TERM

# Prevent race conditions with lock file
exec 200>"$LOCK_FILE"
flock -n 200 || { log "Another instance is running"; exit 1; }

# Handle clipboard data
handle_clipboard() {
  local temp_file="$1"
  if wl-paste --no-newline > "$temp_file" 2>/dev/null; then
    log "Successfully read clipboard"
  else
    log "Failed to read clipboard, assuming empty"
    : > "$temp_file"  # Create empty file to allow empty clipboard sync
  fi
}

case "$MODE" in
  host)
    mkfifo "$FIFO" || { log "Failed to create FIFO"; exit 1; }

    # Broadcast clipboard changes to all connected VMs
    socat -u OPEN:"$FIFO",rdonly TCP4-LISTEN:$PORT_BROADCAST,reuseaddr,fork &
    PIDS+=($!)
    log "Started broadcast listener on port $PORT_BROADCAST"

    # Watch host clipboard using wl-paste --watch
    (
      LAST_HASH=""
      export LAST_HASH
      wl-paste --watch sh -c '
        TEMP_FILE="$1"
        FIFO="$2"
        if wl-paste --no-newline > "$TEMP_FILE" 2>/dev/null; then
          echo "[$(date '\''+%Y-%m-%d %H:%M:%S'\'')] host: Successfully read clipboard"
        else
          echo "[$(date '\''+%Y-%m-%d %H:%M:%S'\'')] host: Failed to read clipboard, assuming empty"
          : > "$TEMP_FILE"
        fi
        NEW_HASH=$(sha256sum "$TEMP_FILE" 2>/dev/null | cut -d " " -f1 || echo "")
        if [[ -z "$NEW_HASH" ]]; then
          echo "[$(date '\''+%Y-%m-%d %H:%M:%S'\'')] host: Failed to compute hash, skipping"
          exit 0
        fi
        if [[ "$NEW_HASH" != "$LAST_HASH" ]]; then
          echo "[$(date '\''+%Y-%m-%d %H:%M:%S'\'')] host: Host clipboard changed"
          cat "$TEMP_FILE" > "$FIFO"
          export LAST_HASH="$NEW_HASH"
        fi
      ' sh "$TMP_DIR/clip.dat" "$FIFO" &
      PIDS+=($!)
    ) &
    PIDS+=($!)

    # Accept clipboard input from VMs and apply to host
    socat -u TCP4-LISTEN:$PORT_SEND,reuseaddr,fork SYSTEM:'wl-copy' &
    PIDS+=($!)
    log "Started receiving listener on port $PORT_SEND"

    wait
    ;;

  vm)
    # Initialize clipboard to ensure accessibility
    wl-copy "" 2>/dev/null || log "Failed to initialize clipboard"

    # Send clipboard changes from VM to host using wl-paste --watch
    (
      LAST_HASH=""
      export LAST_HASH
      wl-paste --watch sh -c '
        TEMP_FILE="$1"
        HOST_IP="$2"
        PORT_SEND="$3"
        TIMEOUT="$4"
        if wl-paste --no-newline > "$TEMP_FILE" 2>/dev/null; then
          echo "[$(date '\''+%Y-%m-%d %H:%M:%S'\'')] vm: Successfully read clipboard"
        else
          echo "[$(date '\''+%Y-%m-%d %H:%M:%S'\'')] vm: Failed to read clipboard, assuming empty"
          : > "$TEMP_FILE"
        fi
        NEW_HASH=$(sha256sum "$TEMP_FILE" 2>/dev/null | cut -d " " -f1 || echo "")
        if [[ -z "$NEW_HASH" ]]; then
          echo "[$(date '\''+%Y-%m-%d %H:%M:%S'\'')] vm: Failed to compute hash, skipping"
          exit 0
        fi
        if [[ "$NEW_HASH" != "$LAST_HASH" ]]; then
          echo "[$(date '\''+%Y-%m-%d %H:%M:%S'\'')] vm: VM clipboard changed, sending to $HOST_IP:$PORT_SEND"
          socat -u OPEN:"$TEMP_FILE",rdonly TCP:"$HOST_IP":"$PORT_SEND",connect-timeout="$TIMEOUT" || {
            echo "[$(date '\''+%Y-%m-%d %H:%M:%S'\'')] vm: Failed to send to host, retrying..."
            exit 1
          }
          export LAST_HASH="$NEW_HASH"
        fi
      ' sh "$TMP_DIR/clip.dat" "$HOST_IP" "$PORT_SEND" "$TIMEOUT" &
      PIDS+=($!)
    ) &
    PIDS+=($!)

    # Receive clipboard updates from host
    while true; do
      socat -u TCP:$HOST_IP:$PORT_BROADCAST,connect-timeout=$TIMEOUT SYSTEM:'wl-copy' || {
        log "Failed to connect to host broadcast, retrying..."
        sleep 1
        continue
      }
    done &
    PIDS+=($!)
    log "Started receiving from $HOST_IP:$PORT_BROADCAST"

    wait
    ;;
esac
