#!/bin/bash

# Installation: 
# move .service and .timer files to ~/.config/systemd/user/
# systemctl --user enable --now service-notify.timer

# Check for failed systemd services
FAILED_SERVICES=$(systemctl --failed --no-legend | awk '{print $1 $2}')

# If there are failed services, send a notification
if [ -n "$FAILED_SERVICES" ]; then
    notify-send -u critical "Systemd Service Failure" "The following services have failed:\n$FAILED_SERVICES"
fi
