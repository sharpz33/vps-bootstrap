#!/bin/bash
set -euo pipefail

# SOPS + Age Setup

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

log "Starting SOPS + Age setup..."

# Install Age
log "Installing Age..."

AGE_VERSION="1.1.1"
AGE_URL="https://github.com/FiloSottile/age/releases/download/v${AGE_VERSION}/age-v${AGE_VERSION}-linux-amd64.tar.gz"

if command -v age &> /dev/null; then
    log "Age already installed: $(age --version)"
else
    log "Downloading Age v${AGE_VERSION}..."
    cd /tmp
    wget -q "$AGE_URL" -O age.tar.gz
    tar xzf age.tar.gz
    mv age/age age/age-keygen /usr/local/bin/
    chmod +x /usr/local/bin/age /usr/local/bin/age-keygen
    rm -rf age age.tar.gz
    log "Age installed successfully"
fi

age --version

# Install SOPS
log "Installing SOPS..."

SOPS_VERSION="3.8.1"
SOPS_URL="https://github.com/getsops/sops/releases/download/v${SOPS_VERSION}/sops-v${SOPS_VERSION}.linux.amd64"

if command -v sops &> /dev/null; then
    log "SOPS already installed: $(sops --version)"
else
    log "Downloading SOPS v${SOPS_VERSION}..."
    wget -q "$SOPS_URL" -O /usr/local/bin/sops
    chmod +x /usr/local/bin/sops
    log "SOPS installed successfully"
fi

sops --version

# Set up Age key directory for root
log "Setting up Age key directory for root..."
mkdir -p /root/.config/sops/age
chmod 700 /root/.config/sops/age

# Set up Age key directory for sudo user (if exists)
if [ -n "${SUDO_USER:-}" ]; then
    SUDO_HOME=$(eval echo ~$SUDO_USER)
    log "Setting up Age key directory for $SUDO_USER..."
    mkdir -p "$SUDO_HOME/.config/sops/age"
    chown -R "$SUDO_USER:$SUDO_USER" "$SUDO_HOME/.config/sops"
    chmod 700 "$SUDO_HOME/.config/sops/age"
fi

# Create example SOPS config
log "Creating example SOPS config..."
cat > /root/.sops.yaml <<'EOF'
# SOPS configuration
# Use Age for encryption

creation_rules:
  - path_regex: \.yaml$
    age: >-
      age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
  - path_regex: \.env$
    age: >-
      age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
EOF

log ""
log "SOPS + Age setup completed successfully"
log ""
log "Next steps:"
log "1. Generate Age key pair:"
log "   age-keygen -o ~/.config/sops/age/keys.txt"
log ""
log "2. Extract public key:"
log "   grep 'public key:' ~/.config/sops/age/keys.txt"
log ""
log "3. Update .sops.yaml with your public key"
log ""
log "4. Encrypt a file:"
log "   sops -e secrets.yaml > secrets.enc.yaml"
log ""
log "5. Decrypt a file:"
log "   sops -d secrets.enc.yaml"
log ""
log "Age key locations:"
log "  - Root: /root/.config/sops/age/keys.txt"
if [ -n "${SUDO_USER:-}" ]; then
    log "  - $SUDO_USER: $SUDO_HOME/.config/sops/age/keys.txt"
fi
