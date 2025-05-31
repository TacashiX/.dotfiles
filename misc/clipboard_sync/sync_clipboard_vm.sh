#!/bin/bash

HOST_IP="192.168.0.145"
PORT=9888
HOST_PORT=9887
HOST_CLIPBOARD="wl-copy"
CLIPBOARD_OUT="wl-paste"

# Trap to clean up nc process on exit
trap 'kill $(jobs -p) 2>/dev/null; exit' EXIT INT TERM

# Receive host clipboard changes
(
  while true; do
    ncat -l -p $PORT | while IFS= read -r line; do
      if [[ $line == TEXT:* ]]; then
        # Handle text
        echo "${line#TEXT:}" | $HOST_CLIPBOARD
      elif [[ $line == IMAGE:* ]]; then
        # Handle image
        ncat -l -p $PORT | base64 -d | $HOST_CLIPBOARD --type image/png
      fi
    done
  done
) &

# Monitor VM clipboard changes
LAST_CLIP_HASH=""
while true; do
  # Check MIME type of clipboard content
  MIME_TYPE=$($CLIPBOARD_OUT --list-types | head -n1)
  CURRENT_CLIP_HASH=$($CLIPBOARD_OUT --no-newline | sha256sum | cut -d' ' -f1)

  if [ -n "$MIME_TYPE" ] && [ "$CURRENT_CLIP_HASH" != "$LAST_CLIP_HASH" ]; then
    if [[ $MIME_TYPE == text/plain* ]]; then
      # Handle text
      CURRENT_CLIP=$($CLIPBOARD_OUT --no-newline)
      if printf "TEXT:%s" "$CURRENT_CLIP" | ncat --send-only $HOST_IP $HOST_PORT 2>/dev/null; then
        LAST_CLIP_HASH=$CURRENT_CLIP_HASH
      fi
    elif [[ $MIME_TYPE == image/png ]]; then
      # Handle image
      if printf "IMAGE:" | ncat --send-only $HOST_IP $HOST_PORT 2>/dev/null &&
         $CLIPBOARD_OUT --no-newline | base64 | ncat --send-only $HOST_IP $HOST_PORT 2>/dev/null; then
        LAST_CLIP_HASH=$CURRENT_CLIP_HASH
      fi
    fi
  fi
  sleep 0.5
done

# WAYLAND_DISPLAY="wayland-1"

# Send clipboard changes to host
#while clipnotify; do
#    wl-paste | nc $HOST_IP $PORT
#done

