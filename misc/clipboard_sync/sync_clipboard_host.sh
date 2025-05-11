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
    ncat -l -p $PORT | $HOST_CLIPBOARD
done
) &

LAST_CLIP=""
while true; do
    CURRENT_CLIP="$($CLIPBOARD_OUT)"
    if [ "$CURRENT_CLIP" != "$LAST_CLIP" ]; then
        # printf "$CURRENT_CLIP" | ssh -i "$SSH_KEY" "$VM_USER@$VM_IP" 'WAYLAND_DISPLAY=wayland-1 wl-copy'
        printf "$CURRENT_CLIP" | ncat --send-only $VM_IP $VM_PORT
        LAST_CLIP="$CURRENT_CLIP"
    fi
    sleep 0.5
done

# Send host clipboard changes
#clipnotify | while read -r; do
#    wl-paste | ssh -i $SSH_KEY $VM_USER@$VM_IP 'WAYLAND_DISPLAY=wayland-1 wl-copy'
#done
