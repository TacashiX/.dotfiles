#!/bin/bash

# Required packages: cifs-utils rsync gocryptfs
#
# Credential file ideally owned by root with 600 permissions. Format:
# username=bla
# password=bla
#
# For daily backups move or copy .timer and .service files to ~/.config/systemd/user/
# systemctl daemon-reload
# systemctl --user enable --now backup-home.timer

# User needs permissions to run /usr/bin/mount and unmount as sudo with NOPASSWD
SOURCE_DIR="/home/$USER" 
DEST_DIR="/mnt/alexandria"  # Mount point for NAS
NAS_SHARE="//192.168.0.25/Alexandria"  
CRED_FILE="/etc/samba/credentials/Alexandria"
RSYNC_OPTS="-avh --delete --progress"  # rsync options

# Optional part to back up content of encrypted plasma-vaults 
# store vault password in kde wallet or whatever password manager that workds with secret-tool
# secret-tool store --label="CryFS Vault Name" cryfs vault_YourVault
VAULT_ENC_DIR="/home/$USER/.local/share/plasma-vault/jail.enc"
VAULT_MOUNT="/tmp/vault_backup_$$"


EXCLUDE_PATTERNS=(
    "*.cache*"
    "*tmp*"
    ".Trash*"
    "*.bak"
    "*.log"
    "Downloads/*"
    "Games/*"
    "Vaults/*"
    ".*"
)

# Unencrypted vault paths to exclude 
VAULT_EXCLUDE_PATHS=(
    "games"  # Example: exclude ~/Vaults/misc/games/
    "home/downloads"
)

# Function to log messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Check if credentials file exists
if [ ! -f "$CRED_FILE" ]; then
    log "Error: Credentials file $CRED_FILE not found"
    exit 1
fi

# Check if NAS is reachable with retries
NAS_HOST=$(echo "$NAS_SHARE" | sed 's|//*||;s|/.*||')  # Extract hostname/IP
RETRY_COUNT=5
RETRY_DELAY=10
for ((i=1; i<=RETRY_COUNT; i++)); do
    ping -c 1 -W 2 "$NAS_HOST" &> /dev/null
    if [ $? -eq 0 ]; then
        log "NAS at $NAS_HOST is reachable"
        break
    fi
    log "NAS at $NAS_HOST not reachable (attempt $i/$RETRY_COUNT)"
    if [ $i -eq $RETRY_COUNT ]; then
        log "Error: NAS unreachable after $RETRY_COUNT attempts"
        exit 1
    fi
    sleep $RETRY_DELAY
done

# Create mount point if it doesn't exist
if [ ! -d "$DEST_DIR" ]; then
    sudo mkdir -p "$DEST_DIR"
    sudo chown $USER:$USER "$DEST_DIR"
fi

# Mount the NAS
if ! mountpoint -q "$DEST_DIR"; then
    log "Mounting NAS at $DEST_DIR"
    sudo mount -t cifs "$NAS_SHARE" "$DEST_DIR" -o credentials="$CRED_FILE",uid=$UID,gid=$(id -g),vers=3.0
    if [ $? -ne 0 ]; then
        log "Error: Failed to mount NAS"
        exit 1
    fi
fi

# Build rsync exclude options
RSYNC_EXCLUDES=""
for pattern in "${EXCLUDE_PATTERNS[@]}"; do
    RSYNC_EXCLUDES="$RSYNC_EXCLUDES --exclude='$pattern'"
done

# Run rsync for home dir with low priority
log "Starting backup from $SOURCE_DIR to $DEST_DIR/odin-backup"
eval "ionice -c3 nice -n19 rsync $RSYNC_OPTS $RSYNC_EXCLUDES '$SOURCE_DIR/' '$DEST_DIR/odin-backup/'" 2>&1

# Check rsync exit status
if [ $? -eq 0 ]; then
    log "Home backup completed successfully"
else
    log "Home backup failed with error code $?"
    # Still attempt to backup vault
fi


# Back up selected encrypted vault files
BACKUP_ARCHIVE="/tmp/vault_backup_$$.tar.gpg"
VAULT_NAME=$(basename "$VAULT_ENC_DIR" .enc)
if [ -d "$VAULT_ENC_DIR" ]; then
    # Create temporary mount point
    mkdir -p "$VAULT_MOUNT"
    chmod 700 "$VAULT_MOUNT"

    # Retrieve vault password
    VAULT_PASS=$(secret-tool lookup gocryptfs vault_"$VAULT_NAME")
    if [ -z "$VAULT_PASS" ]; then
        log "Error: Failed to retrieve vault password for $VAULT_NAME"
        rm -rf "$VAULT_MOUNT"
        exit 1
    fi

    # Mount the vault
    log "Mounting vault at $VAULT_MOUNT"
    echo "$VAULT_PASS" | gocryptfs -passfile /dev/stdin "$VAULT_ENC_DIR" "$VAULT_MOUNT" >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        log "Error: Failed to mount vault"
        rm -rf "$VAULT_MOUNT"
        exit 1
    fi

    # Build tar exclude options
    TAR_EXCLUDES=""
    for path in "${VAULT_EXCLUDE_PATHS[@]}"; do
        if [ -d "$VAULT_MOUNT/$path" ]; then
            TAR_EXCLUDES="$TAR_EXCLUDES --exclude='$path'"
            log "Excluding directory: $path"
        else
            log "Warning: $path is not a directory in vault"
        fi
    done

    # Create encrypted tar archive
    log "Creating encrypted archive at $BACKUP_ARCHIVE"
    eval "tar -C '$VAULT_MOUNT' --warning=no-file-changed --ignore-failed-read -cf - $TAR_EXCLUDES ." | gpg --batch --pinentry-mode loopback --cipher-algo AES256 --passphrase "$VAULT_PASS" -o "$BACKUP_ARCHIVE" --symmetric 2>&1 #2>/dev/null
    if [ $? -ne 0 ]; then
        log "Error: Failed to create encrypted archive"
        umount "$VAULT_MOUNT" >/dev/null 2>&1
        rm -rf "$VAULT_MOUNT"
        rm -f "$BACKUP_ARCHIVE"
        exit 1
    fi

    # Unmount vault
    log "Unmounting vault from $VAULT_MOUNT"
    umount "$VAULT_MOUNT" >/dev/null 2>&1
    rm -rf "$VAULT_MOUNT"

    # Create vault-backup destination directory
    VAULT_DEST="$DEST_DIR/vault-backup"
    sudo mkdir -p "$VAULT_DEST"
    sudo chown $USER:$USER "$VAULT_DEST"

    # Sync encrypted archive to NAS
    log "Syncing encrypted archive to $VAULT_DEST/vault_backup.tar.gpg"
    ionice -c3 nice -n19 rsync $RSYNC_OPTS "$BACKUP_ARCHIVE" "$VAULT_DEST/vault_backup.tar.gpg" 2>&1
    if [ $? -eq 0 ]; then
        log "Encrypted archive synced successfully"
    else
        log "Error: Failed to sync encrypted archive"
        rm -f "$BACKUP_ARCHIVE"
        exit 1
    fi

    # Clean up temp files
    rm -f "$BACKUP_ARCHIVE"
else
    log "Warning: Encrypted vault directory $VAULT_ENC_DIR not found"
fi

# Unmount the NAS
if mountpoint -q "$DEST_DIR"; then
    log "Unmounting NAS from $DEST_DIR"
    sudo umount "$DEST_DIR"
    if [ $? -ne 0 ]; then
        log "Warning: Failed to unmount NAS"
    fi
fi

exit 0
