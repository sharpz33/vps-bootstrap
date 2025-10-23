#!/bin/bash
set -euo pipefail

# Security Hardening - UFW, fail2ban, SSH

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

log "Starting security hardening..."

# Install UFW
log "Installing UFW firewall..."
apt-get install -y -qq ufw

# Configure UFW rules
log "Configuring UFW rules..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing

# Allow SSH, HTTP, HTTPS
ufw allow 22/tcp comment 'SSH'
ufw allow 80/tcp comment 'HTTP'
ufw allow 443/tcp comment 'HTTPS'

# Enable UFW
log "Enabling UFW..."
ufw --force enable

# Verify UFW status
ufw status numbered

# Install fail2ban
log "Installing fail2ban..."
apt-get install -y -qq fail2ban

# Configure fail2ban
log "Configuring fail2ban..."
cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5
destemail = root@localhost
sendername = Fail2Ban

[sshd]
enabled = true
port = ssh
logpath = %(sshd_log)s
backend = %(sshd_backend)s
maxretry = 3
bantime = 86400
EOF

# Start and enable fail2ban
systemctl enable fail2ban
systemctl restart fail2ban

log "fail2ban status:"
systemctl status fail2ban --no-pager | head -n 10

# SSH Hardening
log "Hardening SSH configuration..."

SSH_CONFIG="/etc/ssh/sshd_config"
SSH_BACKUP="/etc/ssh/sshd_config.backup.$(date +%Y%m%d)"

# Backup original
if [ ! -f "$SSH_BACKUP" ]; then
    cp "$SSH_CONFIG" "$SSH_BACKUP"
    log "SSH config backed up to $SSH_BACKUP"
fi

# Apply hardening
log "Applying SSH security settings..."

# Disable root login
log "Disabling root SSH login..."
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' "$SSH_CONFIG"

# Disable password authentication (SSH keys only)
log "Disabling password authentication (SSH keys only)..."
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' "$SSH_CONFIG"

# Ensure PubkeyAuthentication is enabled
if ! grep -q "^PubkeyAuthentication yes" "$SSH_CONFIG"; then
    sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' "$SSH_CONFIG"
fi

# Other SSH hardening
grep -q "^Protocol 2" "$SSH_CONFIG" || echo "Protocol 2" >> "$SSH_CONFIG"
grep -q "^PermitEmptyPasswords" "$SSH_CONFIG" || echo "PermitEmptyPasswords no" >> "$SSH_CONFIG"
grep -q "^X11Forwarding" "$SSH_CONFIG" || echo "X11Forwarding no" >> "$SSH_CONFIG"
grep -q "^MaxAuthTries" "$SSH_CONFIG" || echo "MaxAuthTries 3" >> "$SSH_CONFIG"
grep -q "^ClientAliveInterval" "$SSH_CONFIG" || echo "ClientAliveInterval 300" >> "$SSH_CONFIG"
grep -q "^ClientAliveCountMax" "$SSH_CONFIG" || echo "ClientAliveCountMax 2" >> "$SSH_CONFIG"

# Test SSH config
log "Testing SSH configuration..."
sshd -t

if [ $? -eq 0 ]; then
    log "SSH config test passed"
    systemctl restart sshd
    log "SSH service restarted"
else
    log "ERROR: SSH config test failed. Reverting to backup."
    cp "$SSH_BACKUP" "$SSH_CONFIG"
    systemctl restart sshd
    exit 1
fi

log "Security hardening completed successfully"
log ""
log "IMPORTANT: Current security status:"
log "  - UFW enabled (ports 22, 80, 443 open)"
log "  - fail2ban active (SSH brute-force protection)"
log "  - SSH root login: DISABLED"
log "  - SSH password auth: DISABLED (SSH keys only)"
log "  - Public key authentication: ENABLED"
