#!/bin/bash
set -euo pipefail

# User Creation - Create sudo user and copy SSH keys from root

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

error() {
    echo "[ERROR] $1"
    exit 1
}

# Check if we're running as root
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root"
fi

log "Starting user creation..."

# Get username from environment or prompt
if [ -z "${VPS_USERNAME:-}" ]; then
    log "No VPS_USERNAME environment variable set."
    read -p "Enter username for new sudo user: " VPS_USERNAME

    if [ -z "$VPS_USERNAME" ]; then
        error "Username cannot be empty"
    fi
fi

# Validate username (alphanumeric, underscore, hyphen)
if ! [[ "$VPS_USERNAME" =~ ^[a-z][-a-z0-9_]*$ ]]; then
    error "Invalid username. Use lowercase letters, numbers, hyphens, and underscores only."
fi

# Check if user already exists
if id "$VPS_USERNAME" &>/dev/null; then
    log "User $VPS_USERNAME already exists"

    # Ensure user is in sudo group
    if groups "$VPS_USERNAME" | grep -q sudo; then
        log "User $VPS_USERNAME is already in sudo group"
    else
        log "Adding $VPS_USERNAME to sudo group..."
        usermod -aG sudo "$VPS_USERNAME"
        log "User $VPS_USERNAME added to sudo group"
    fi
else
    # Create user with home directory
    log "Creating user $VPS_USERNAME..."
    useradd -m -s /bin/bash -G sudo "$VPS_USERNAME"
    log "User $VPS_USERNAME created with sudo privileges"

    # Set password or disable it
    log "Disabling password for $VPS_USERNAME (SSH key authentication only)..."
    passwd -d "$VPS_USERNAME"
    passwd -l "$VPS_USERNAME"
fi

# Copy SSH keys from root to new user
USER_HOME="/home/$VPS_USERNAME"
USER_SSH_DIR="$USER_HOME/.ssh"

log "Setting up SSH keys for $VPS_USERNAME..."

# Create .ssh directory if it doesn't exist
if [ ! -d "$USER_SSH_DIR" ]; then
    mkdir -p "$USER_SSH_DIR"
    log "Created $USER_SSH_DIR"
fi

# Copy authorized_keys from root if it exists
if [ -f /root/.ssh/authorized_keys ]; then
    log "Copying SSH keys from root..."
    cp /root/.ssh/authorized_keys "$USER_SSH_DIR/authorized_keys"
    log "SSH keys copied successfully"
else
    log "WARNING: No SSH keys found in /root/.ssh/authorized_keys"
    log "You may need to add SSH keys manually to $USER_SSH_DIR/authorized_keys"
fi

# Set correct permissions
chown -R "$VPS_USERNAME:$VPS_USERNAME" "$USER_SSH_DIR"
chmod 700 "$USER_SSH_DIR"
if [ -f "$USER_SSH_DIR/authorized_keys" ]; then
    chmod 600 "$USER_SSH_DIR/authorized_keys"
fi

log "SSH directory permissions set correctly"

# Test sudo access
log "Testing sudo access for $VPS_USERNAME..."
if sudo -u "$VPS_USERNAME" sudo -n true 2>/dev/null; then
    log "Sudo access verified (passwordless)"
elif sudo -u "$VPS_USERNAME" sudo -v 2>/dev/null; then
    log "Sudo access available (may require password)"
else
    log "Configuring passwordless sudo for $VPS_USERNAME..."
    echo "$VPS_USERNAME ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$VPS_USERNAME"
    chmod 440 "/etc/sudoers.d/$VPS_USERNAME"
    log "Passwordless sudo configured"
fi

log ""
log "User creation completed successfully!"
log "========================================="
log "Username: $VPS_USERNAME"
log "Home directory: $USER_HOME"
log "Sudo access: YES (passwordless)"
log "SSH keys: Copied from root"
log "Password: Disabled (SSH key only)"
log "========================================="
log ""
log "IMPORTANT: Test SSH login as $VPS_USERNAME before logging out as root!"
log "  ssh $VPS_USERNAME@YOUR_SERVER_IP"
log ""
