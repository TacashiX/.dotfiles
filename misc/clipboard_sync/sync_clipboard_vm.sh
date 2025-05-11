#!/bin/bash
HOST_IP="<host-ip>"
PORT=9888
HOST_PORT=9887
# WAYLAND_DISPLAY="wayland-1"

# Send clipboard changes to host
#while clipnotify; do
#    wl-paste | nc $HOST_IP $PORT
#done

(
	while true; do
		ncat -l -p $PORT | wl-copy
	done
) &

LAST_CLIP=""
while true; do
    CURRENT_CLIP="$(wl-paste)"
    if [ "$CURRENT_CLIP" != "$LAST_CLIP" ]; then
        printf "$CURRENT_CLIP" | ncat --send-only $HOST_IP $HOST_PORT
        LAST_CLIP="$CURRENT_CLIP"
    fi
    sleep 0.5
done
