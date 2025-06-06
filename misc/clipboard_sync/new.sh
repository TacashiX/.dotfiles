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

# Determine mime type of clipboard content
get_mime_type() {
  wl-paste --list-types 2>/dev/null | head -n1 || echo "text/plain"
}

# Handle clipboard data based on mime type
handle_clipboard() {
  local temp_file="$1"
  local mime_type=$(get_mime_type)
  if [[ -z "$mime_type" ]]; then
    log "No mime type detected, assuming text/plain"
    mime_type="text/plain"
  fi
  if [[ "$mime_type" =~ ^text/ ]]; then
    if wl-paste --no-newline > "$temp_file" 2>/dev/null; then
      log "Successfully read text clipboard (mime: $mime_type)"
    else
      log "Failed to read text clipboard, assuming empty"
      : > "$temp_file"  # Create empty file to avoid skipping
    fi
  else
    if wl-paste > "$temp_file" 2>/dev/null; then
      log "Successfully read non-text clipboard (mime: $mime_type)"
    else
      log "Failed to read non-text clipboard, assuming empty"
      : > "$temp_file"
    fi
  fi
  echo "$mime_type"
}

case "$MODE" in
  host)
    mkfifo "$FIFO" || { log "Failed to create FIFO"; exit 1; }

    # Broadcast clipboard changes to all connected VMs
    socat -u OPEN:"$FIFO",rdonly TCP4-LISTEN:$PORT_BROADCAST,reuseaddr,fork &
    PIDS+=($!)
    log "Started broadcast listener on port $PORT_BROADCAST"

    # Watch host clipboard and write to FIFO
    (
      LAST_HASH=""
      while true; do
        TEMP_FILE="$TMP_DIR/clip.dat"
        MIME_TYPE=$(handle_clipboard "$TEMP_FILE")
        if [[ ! -s "$TEMP_FILE" ]]; then
          sleep 0.3
          continue
        fi
        NEW_HASH=$(sha256sum "$TEMP_FILE" | cut -d ' ' -f1)
        if [[ "$NEW_HASH" != "$LAST_HASH" ]]; then
          log "Host clipboard changed (mime: $MIME_TYPE)"
          cat "$TEMP_FILE" > "$FIFO"
          LAST_HASH="$NEW_HASH"
        fi
        sleep 0.3
      done
    ) &
    PIDS+=($!)

    # Accept clipboard input from VMs and apply to host
    socat -u TCP4-LISTEN:$PORT_SEND,reuseaddr,fork SYSTEM:'wl-copy' &
    PIDS+=($!)
    log "Started receiving listener on port $PORT_SEND"

    wait
    ;;

  vm)
    # Send clipboard changes from VM to host
    (
      LAST_HASH=""
      # Initialize clipboard to ensure it's accessible
      wl-copy "" 2>/dev/null || log "Failed to initialize clipboard"
      while true; do
        TEMP_FILE="$TMP_DIR/clip.dat"
        MIME_TYPE=$(handle_clipboard "$TEMP_FILE")
        if [[ ! -s "$TEMP_FILE" && "$MIME_TYPE" != "text/plain" ]]; then
          log "Empty clipboard (non-text), skipping"
          sleep 0.3
          continue
        fi
        NEW_HASH=$(sha256sum "$TEMP_FILE" 2>/dev/null | cut -d ' ' -f1 || echo "")
        if [[ -z "$NEW_HASH" ]]; then
          log "Failed to compute hash, skipping"
          sleep 0.3
          continue
        fi
        if [[ "$NEW_HASH" != "$LAST_HASH" ]]; then
          log "VM clipboard changed (mime: $MIME_TYPE), sending to $HOST_IP:$PORT_SEND"
          socat -u OPEN:"$TEMP_FILE",rdonly TCP:$HOST_IP:$PORT_SEND,connect-timeout=$TIMEOUT || {
            log "Failed to send to host, retrying..."
            sleep 1
            continue
          }
          LAST_HASH="$NEW_HASH"
        fi
        sleep 0.3
      done
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
