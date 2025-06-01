#!/bin/bash

# Arguments: $1 = domain, $2 = action (start, stop, etc)
VM_NAME="$1"
EVENT_TYPE="$2"

USER="chris"
SERVICE="clipboard-sync-host.service"

# Helper to run systemctl as user
run_user() {
  sudo -u "$USER" XDG_RUNTIME_DIR="/run/user/$(id -u $USER)" systemctl --user "$@"
}

case "$EVENT_TYPE" in
  started|prepare)
    run_user start "$SERVICE"
    ;;

  stopped|release)
    # If no more running VMs, stop the service
    VM_COUNT=$(virsh list --state-running --name | grep -v '^$' | wc -l)
    if [ "$VM_COUNT" -eq 0 ]; then
      run_user stop "$SERVICE"
    fi
    ;;
esac

