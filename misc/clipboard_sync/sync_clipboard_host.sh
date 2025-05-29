#!/bin/bash


#Simple script to sync host and guest clipboards since vdagent will not work for some reason.

#Installation: 
#- Start sync_clipboard_vm.sh once in your window manager config
#- Add the content of hooks.sh to your existing libvirt qemu hooks if you have any, otherwise just create the directory and file (/etc/libvirt/hooks/qemu)


#!/bin/bash
VM_USER="chris"
VM_IP="192.168.122.198"
SSH_KEY="~/.ssh/vm_clipboard"
PORT=9887
VM_PORT=9888
HOST_CLIPBOARD="wl-copy" 
CLIPBOARD_OUT="wl-paste"

# Trap to clean up nc process on exit
trap 'kill $(jobs -p) 2>/dev/null; exit' EXIT INT TERM

# Receive VM clipboard changes
(
  while true; do
    ncat -l -p $PORT | while IFS= read -r line; do
      if [[ $line == TEXT:* ]]; then
        # Handle text
        echo "${line#TEXT:}" | $HOST_CLIPBOARD
      elif [[ $line == IMAGE:* ]]; then
        # Handle image
        ncat -l -p $PORT | base64 -d | $HOST_CLIPBOARD --type image/png
      elif [[ $line == FILE:* ]]; then
        # Handle file
        FILENAME="${line#FILE:}"
        ncat -l -p $PORT | base64 -d > "/tmp/$FILENAME"
        echo "file:///tmp/$FILENAME" | $HOST_CLIPBOARD
      fi
    done
  done
) &

# Monitor host clipboard changes
LAST_CLIP_HASH=""
while true; do
  # Check MIME type of clipboard content
  MIME_TYPE=$($CLIPBOARD_OUT --list-types | head -n1)
  CURRENT_CLIP_HASH=$($CLIPBOARD_OUT --no-newline | sha256sum | cut -d' ' -f1)

  if [ -n "$MIME_TYPE" ] && [ "$CURRENT_CLIP_HASH" != "$LAST_CLIP_HASH" ]; then
    if [[ $MIME_TYPE == text/plain* ]]; then
      # Handle text
      CURRENT_CLIP=$($CLIPBOARD_OUT --no-newline)
      if printf "TEXT:%s" "$CURRENT_CLIP" | ncat --send-only $VM_IP $VM_PORT 2>/dev/null; then
        LAST_CLIP_HASH=$CURRENT_CLIP_HASH
      fi
    elif [[ $MIME_TYPE == image/png ]]; then
      # Handle image
      if printf "IMAGE:" | ncat --send-only $VM_IP $VM_PORT 2>/dev/null &&
         $CLIPBOARD_OUT --no-newline | base64 | ncat --send-only $VM_IP $VM_PORT 2>/dev/null; then
        LAST_CLIP_HASH=$CURRENT_CLIP_HASH
      fi
    elif [[ $MIME_TYPE == text/uri-list ]]; then
      # Handle file
      FILE_PATH=$($CLIPBOARD_OUT --no-newline | sed 's|^file://||')
      if [ -f "$FILE_PATH" ]; then
        FILENAME=$(basename "$FILE_PATH")
        if printf "FILE:%s" "$FILENAME" | ncat --send-only $VM_IP $VM_PORT 2>/dev/null &&
           cat "$FILE_PATH" | base64 | ncat --send-only $VM_IP $VM_PORT 2>/dev/null; then
          LAST_CLIP_HASH=$CURRENT_CLIP_HASH
        fi
      fi
    fi
  fi
  sleep 0.5
done

# Send host clipboard changes
#clipnotify | while read -r; do
#    wl-paste | ssh -i $SSH_KEY $VM_USER@$VM_IP 'WAYLAND_DISPLAY=wayland-1 wl-copy'
#done
