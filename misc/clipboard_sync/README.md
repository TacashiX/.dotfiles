# Clipboard Sync Setup

Scripts to sync clipboards between Wayland based Host and VMs over TCP since guest agents keep failing me for some reason.

## Requirements

- `wl-clipboard`
- `socat`
- Wayland-based session (tested with Hyprland/KDE)

## Installation

Set `HOST_IP` in `clipboard_sync.sh` and `USER` in `libvirt_qemu_hook.sh`.

### Host Setup

#### Symlink systemd service
Do not enable this service. Starting and stopping is taken care of by the QEMU hook.

```bash
mkdir -p ~/.config/systemd/user
ln -s ~/.dotfiles/misc/clipboard_sync/clipboard-sync-host.service ~/.config/systemd/user/

systemctl --user daemon-reload
```

#### Set up QEMU hook

```bash
sudo mkdir -p /etc/libvirt/hooks/qemu.d
sudo ln -sf ~/.dotfiles/misc/clipboard_sync/libvirt_qemu_hook.sh /etc/libvirt/hooks/qemu.d/clipboard-sync-hook.sh
```

### VM Setup

#### Install and start service

```bash
mkdir -p ~/.config/systemd/user
ln -s ~/.dotfiles/misc/clipboard_sync/clipboard-sync-vm.service ~/.config/systemd/user/

systemctl --user daemon-reload
systemctl --user enable --now clipboard-sync-vm.service
```
