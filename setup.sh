#!/bin/bash
set -euo pipefail

# VPS Bootstrap - Main Setup Orchestrator
# Ubuntu 24.04 LTS only

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/vps-bootstrap.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
    exit 1
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_FILE"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (use sudo)"
    fi
}

check_os() {
    if [ ! -f /etc/os-release ]; then
        error "Cannot detect OS. /etc/os-release not found."
    fi
    
    . /etc/os-release
    
    if [[ "$ID" != "ubuntu" ]]; then
        error "Unsupported OS: $ID. This script only supports Ubuntu."
    fi
    
    if [[ "$VERSION_ID" != "24.04" ]]; then
        warn "Detected Ubuntu $VERSION_ID. This script is tested on 24.04 LTS only."
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    log "OS check passed: Ubuntu $VERSION_ID"
}

run_script() {
    local script=$1
    local name=$2
    
    log "Running: $name"
    
    if [ ! -f "$SCRIPT_DIR/scripts/$script" ]; then
        error "Script not found: $script"
    fi
    
    chmod +x "$SCRIPT_DIR/scripts/$script"
    
    if bash "$SCRIPT_DIR/scripts/$script"; then
        log "✓ $name completed successfully"
    else
        error "✗ $name failed"
    fi
}

main() {
    log "======================================"
    log "VPS Bootstrap - Starting Setup"
    log "======================================"

    check_root
    check_os

    # Run setup scripts in order
    run_script "00-user.sh" "User Creation"
    run_script "01-system.sh" "System Setup"
    run_script "02-security.sh" "Security Hardening"
    run_script "03-docker.sh" "Docker Installation"
    run_script "05-sops.sh" "SOPS + Age Setup"
    run_script "04-monitoring.sh" "Monitoring Setup"

    log "======================================"
    log "✓ VPS Bootstrap completed successfully"
    log "======================================"
    log ""
    log "CRITICAL: SSH root login is now DISABLED"
    log ""
    log "Next steps:"
    log "1. Test SSH login as new user BEFORE disconnecting root session"
    log "   (open new terminal: ssh USERNAME@YOUR_SERVER_IP)"
    log "2. Configure Age key: ~/.config/sops/age/keys.txt"
    log "3. Test Discord alerts (if webhook provided)"
    log "4. Reboot recommended: sudo reboot"
    log ""
    log "Log file: $LOG_FILE"
}

main "$@"
