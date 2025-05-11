#!/bin/bash

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
            for i in {1..30}; do
                if ping -c 1 $VM_IP &>/dev/null; then
                    su "$USER" -c "bash $SCRIPT & echo \$! > $PID_FILE" >> "$LOG_FILE" 2>&1
                    echo "$(date) PID written: $(cat $PID_FILE)" >> "$LOG_FILE"
                    exit 0
                fi
                sleep 1
            done
            echo "$(date) Failed to ping $VM_IP" >> "$LOG_FILE"
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
            pkill -u "$USER" -f 'nc -l 9887'
            pkill -u "$USER" -f 'ssh.*wl-copy'
            echo "$(date) Cleanup complete" >> "$LOG_FILE"
            ;;
    esac
fi
