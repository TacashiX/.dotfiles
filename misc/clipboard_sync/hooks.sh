#!/bin/bash
#if [[ "$2" == "stopped" || "$2" == "reboot" ]]; then
#    echo 1 > /sys/bus/pci/devices/0000:12:00.0/reset
#    echo 1 > /sys/bus/pci/devices/0000:12:00.1/reset
#fi

# Hook script to adjust /dev/shm/looking-glass permissions
if [ "$1" = "win-11" ] && [ "$2" = "started" ]; then
    SHM_FILE="/dev/shm/looking-glass"
    if [ -f "$SHM_FILE" ]; then
        chgrp libvirt "$SHM_FILE"
        chmod 660 "$SHM_FILE"
        logger "Adjusted permissions for $SHM_FILE"
    fi
fi

if [ "$1" = "blackarch" ]; then
    VM_IP="192.168.122.198"
    USER="chris"
    SCRIPT="/home/$USER/.dotfiles/misc/clipboard_sync/sync_clipboard_host.sh"
    PID_FILE="/tmp/vm_clip.pid"
    LOG_FILE="/tmp/vm_hook.log"

    echo "$(date) Hook called: $1 $2" >> "$LOG_FILE"

    case "$2" in
        started)
            echo "$(date) Starting $SCRIPT" >> "$LOG_FILE"
            su "$USER" -c "export XDG_SESSION_TYPE=wayland; export XDG_RUNTIME_DIR=/run/user/1000; export WAYLAND_DISPLAY=wayland-0; nohup bash $SCRIPT >/dev/null & echo \$! > $PID_FILE" >> "$LOG_FILE" 2>&1
            echo "$(date) PID written: $(cat $PID_FILE)" >> "$LOG_FILE"
            ;;
        stopped|release)
            echo "$(date) Stopping $SCRIPT" >> "$LOG_FILE"
            if [ -f "$PID_FILE" ]; then
                PID=$(cat "$PID_FILE")
                if [ -n "$PID" ]; then
                    kill -9 "$PID" 2>/dev/null
                    echo "$(date) Killed PID $PID" >> "$LOG_FILE"
                fi
                rm -f "$PID_FILE"
            fi
            pkill -u "$USER" -f "$SCRIPT"
            pkill -u "$USER" -f 'ncat -l -p 9887'
            pkill -u "$USER" -f 'ssh.*wl-copy'
            echo "$(date) Cleanup complete" >> "$LOG_FILE"
            ;;
    esac
fi

