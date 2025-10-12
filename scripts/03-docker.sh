#!/bin/bash
set -euo pipefail

# Docker Installation

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

log "Starting Docker installation..."

# Check if Docker is already installed
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version)
    log "Docker already installed: $DOCKER_VERSION"
    log "Skipping Docker installation"
else
    log "Docker not found, proceeding with installation..."
    
    # Remove old versions if any
    log "Removing old Docker versions (if any)..."
    apt-get remove -y -qq docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Install prerequisites
    log "Installing prerequisites..."
    apt-get update -qq
    apt-get install -y -qq \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    
    # Add Docker's official GPG key
    log "Adding Docker GPG key..."
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    
    # Set up Docker repository
    log "Adding Docker repository..."
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker Engine
    log "Installing Docker Engine..."
    apt-get update -qq
    apt-get install -y -qq \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin
    
    log "Docker installed successfully"
fi

# Verify Docker installation
log "Verifying Docker installation..."
docker --version
docker compose version

# Enable and start Docker service
log "Enabling Docker service..."
systemctl enable docker
systemctl start docker

# Add current user to docker group (if not root)
if [ -n "${SUDO_USER:-}" ]; then
    log "Adding user $SUDO_USER to docker group..."
    usermod -aG docker "$SUDO_USER"
    log "User $SUDO_USER added to docker group (logout required to take effect)"
fi

# Test Docker
log "Testing Docker..."
if docker run --rm hello-world > /dev/null 2>&1; then
    log "Docker test passed"
else
    log "WARNING: Docker test failed"
fi

# Configure Docker daemon (optional optimizations)
log "Configuring Docker daemon..."
mkdir -p /etc/docker

cat > /etc/docker/daemon.json <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2"
}
EOF

# Restart Docker to apply config
systemctl restart docker

log "Docker installation and configuration completed successfully"
log ""
log "Docker info:"
docker info | grep -E "Server Version|Storage Driver|Logging Driver" || true
