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
VAULT_MOUNT="/home/$USER/vault_backup_$$"
TEMP_ARCHIVE_DIR="/home/$USER/tmp"
BACKUP_ARCHIVE="$TEMP_ARCHIVE_DIR/vault_backup_$$.tar.gpg"

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
    "home/games" 
    "home/downloads"
)

# Function to log messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Cleanup function for unmounting and removing temp files
cleanup() {
    log "Starting cleanup"
    # Unmount vault if mounted
    if mountpoint -q "$VAULT_MOUNT" 2>/dev/null; then
        log "Unmounting vault from $VAULT_MOUNT"
        fusermount -u "$VAULT_MOUNT" >/dev/null 2>&1 || log "Warning: Failed to unmount vault"
    fi
    # Remove vault mount point
    [ -d "$VAULT_MOUNT" ] && rm -rf "$VAULT_MOUNT" && log "Removed vault mount point $VAULT_MOUNT"
    
    # Unmount NAS if mounted
    if mountpoint -q "$DEST_DIR" 2>/dev/null; then
        log "Unmounting NAS from $DEST_DIR"
        sudo umount "$DEST_DIR" >/dev/null 2>&1 || log "Warning: Failed to unmount NAS"
    fi
    
    # Remove temporary archive if it exists
    [ -f "$BACKUP_ARCHIVE" ] && rm -f "$BACKUP_ARCHIVE" && log "Removed temporary archive $BACKUP_ARCHIVE"
    
    # Remove temporary archive directory if empty
    [ -d "$TEMP_ARCHIVE_DIR" ] && rmdir "$TEMP_ARCHIVE_DIR" 2>/dev/null && log "Removed temporary archive directory $TEMP_ARCHIVE_DIR"
}

trap cleanup EXIT INT TERM

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
VAULT_NAME=$(basename "$VAULT_ENC_DIR" .enc)
if [ -d "$VAULT_ENC_DIR" ]; then
    # Create temporary mount point
    mkdir -p "$VAULT_MOUNT"
    chmod 700 "$VAULT_MOUNT"

    # Retrieve vault password
    VAULT_PASS=$(secret-tool lookup gocryptfs vault_"$VAULT_NAME" 2>/dev/null || secret-tool lookup plasma-vault "$VAULT_NAME")
    if [ -z "$VAULT_PASS" ]; then
        log "Error: Failed to retrieve vault password for $VAULT_NAME"
        exit 1
    fi

    # Mount the vault
    log "Mounting vault at $VAULT_MOUNT"
    echo "$VAULT_PASS" | gocryptfs -passfile /dev/stdin "$VAULT_ENC_DIR" "$VAULT_MOUNT" >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        log "Error: Failed to mount vault"
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

    # Create temporary archive directory
    sudo mkdir -p "$TEMP_ARCHIVE_DIR"
    sudo chown $USER:$USER "$TEMP_ARCHIVE_DIR"

    # Create encrypted tar archive
    log "Creating encrypted archive at $BACKUP_ARCHIVE"
    tar -C "$VAULT_MOUNT" -cf - $TAR_EXCLUDES . 2>/tmp/tar_error.log | gpg --batch --pinentry-mode loopback --cipher-algo AES256 --passphrase "$VAULT_PASS" -o "$BACKUP_ARCHIVE" --symmetric 2>/tmp/gpg_error.log
    if [ ${PIPESTATUS[0]} -ne 0 ] || [ ${PIPESTATUS[1]} -ne 0 ]; then
        log "Error: Failed to create encrypted archive"
        log "tar errors: $(cat /tmp/tar_error.log)"
        log "gpg errors: $(cat /tmp/gpg_error.log)"
        rm -f /tmp/tar_error.log /tmp/gpg_error.log
        exit 1
    fi
    rm -f /tmp/tar_error.log /tmp/gpg_error.log

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
        exit 1
    fi
else
    log "Warning: Encrypted vault directory $VAULT_ENC_DIR not found"
fi

exit 0
