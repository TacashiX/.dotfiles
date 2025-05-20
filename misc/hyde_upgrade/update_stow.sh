#!/bin/bash

# Script to remove default configuration files and restow overrides from $HOME/.dotfiles/hyde.
# Assumes stow package 'hyde' in $HOME/.dotfiles, with .config/ subdirectories and .zshrc.

set -euo pipefail

# Define directories
STOW_DIR="$HOME/.dotfiles"
PACKAGE="hyde"
TARGET_DIR="$HOME"

# Function to print usage
usage() {
    echo "Usage: $0"
    echo "  Removes default configs and stows $STOW_DIR/$PACKAGE to $TARGET_DIR"
    exit 1
}

# Check for no arguments
if [ $# -ne 0 ]; then
    usage
fi

# Validate directories
if [ ! -d "$STOW_DIR/$PACKAGE" ]; then
    echo "Error: Stow package directory '$STOW_DIR/$PACKAGE' does not exist."
    exit 1
fi

# Ensure stow is installed
if ! command -v stow &> /dev/null; then
    echo "Error: GNU Stow is not installed. Please install it."
    exit 1
fi

# Function to check if a file is a symlink
is_symlink() {
    [ -L "$1" ]
}

# Function to remove default files that match stow package files
remove_defaults() {
    local package_dir="$1"
    local target_dir="$2"

    # Find all files in the stow package
    while IFS= read -r file; do
        # Get the relative path of the file in the stow package
        relative_path=${file#"$package_dir/"}
        target_path="$target_dir/$relative_path"

        # Check if the target file exists and is not a symlink
        if [ -f "$target_path" ] && ! is_symlink "$target_path"; then
            echo "Removing default file: $target_path"
            rm -f "$target_path"
        fi
    done < <(find "$package_dir" -type f)
}

# Unstow existing symlinks
echo "Unstowing package: $PACKAGE"
stow -D --dir="$STOW_DIR" --target="$TARGET_DIR" "$PACKAGE"

# Remove default files for the package
echo "Removing default files for package: $PACKAGE"
remove_defaults "$STOW_DIR/$PACKAGE" "$TARGET_DIR"

# Stow the package
echo "Stowing package: $PACKAGE"
stow --dir="$STOW_DIR" --target="$TARGET_DIR" "$PACKAGE"

echo "Done! Default files removed and $PACKAGE package stowed."
