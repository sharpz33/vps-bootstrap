#!/bin/bash
set -euo pipefail

# Preflight Checks - Validate system requirements before installation

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
source "$SCRIPT_DIR/lib/helpers.sh"

log_info "Running preflight checks..."

# Track if any checks failed
FAILED_CHECKS=0

# ============================================================================
# Helper function for checks
# ============================================================================

abort() {
    local requirement="$1"
    log_error "Required: $requirement"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
}

# ============================================================================
# System Checks
# ============================================================================

# Check 1: Must be run as root
log "Checking: Running as root..."
if [ "$EUID" -ne 0 ]; then
    log_error "This script must be run as root (use sudo)"
    exit 1
fi
log_success "Running as root: OK"

# Check 2: Must be Ubuntu
log "Checking: Ubuntu distribution..."
if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [[ "$ID" != "ubuntu" ]]; then
        abort "Ubuntu distribution (found: $ID)"
    else
        log_success "Ubuntu detected: $VERSION"
    fi
else
    abort "Ubuntu distribution (cannot detect OS)"
fi

# Check 3: Must be x86_64 architecture
log "Checking: CPU architecture..."
ARCH=$(uname -m)
if [ "$ARCH" != "x86_64" ]; then
    abort "x86_64 CPU architecture (found: $ARCH)"
else
    log_success "Architecture: $ARCH"
fi

# Check 4: Minimum RAM (512MB)
log "Checking: RAM availability..."
TOTAL_RAM=$(free -m | awk '/^Mem:/{print $2}')
MIN_RAM=512
if [ "$TOTAL_RAM" -lt "$MIN_RAM" ]; then
    abort "Minimum ${MIN_RAM}MB RAM (found: ${TOTAL_RAM}MB)"
else
    log_success "RAM: ${TOTAL_RAM}MB (minimum: ${MIN_RAM}MB)"
fi

# Check 5: Available disk space (5GB)
log "Checking: Disk space..."
AVAILABLE_SPACE=$(df / | awk 'NR==2 {print int($4/1024)}')
MIN_SPACE=5120  # 5GB in MB
if [ "$AVAILABLE_SPACE" -lt "$MIN_SPACE" ]; then
    abort "Minimum 5GB free disk space (found: ${AVAILABLE_SPACE}MB)"
else
    log_success "Disk space: ${AVAILABLE_SPACE}MB available"
fi

# Check 6: Internet connectivity
log "Checking: Internet connectivity..."
if ! ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
    abort "Internet connectivity (cannot reach 8.8.8.8)"
else
    if ! ping -c 1 -W 2 google.com >/dev/null 2>&1; then
        abort "DNS resolution (cannot resolve google.com)"
    else
        log_success "Internet connectivity: OK"
    fi
fi

# Check 7: APT is not locked
log "Checking: APT lock status..."
if fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; then
    abort "APT is not locked (another package manager is running)"
else
    log_success "APT: Available"
fi

# Check 8: systemd is running
log "Checking: systemd..."
if ! pidof systemd >/dev/null 2>&1; then
    abort "systemd init system"
else
    log_success "systemd: Running"
fi

# ============================================================================
# Summary and Confirmation
# ============================================================================

echo ""
echo "================================================================="
if [ $FAILED_CHECKS -eq 0 ]; then
    log_success "All preflight checks passed!"
    echo "================================================================="
    echo ""
else
    log_warning "Failed checks: $FAILED_CHECKS"
    echo "================================================================="
    echo ""

    # Ask if user wants to proceed anyway
    read -p "Some checks failed. Proceed anyway at your own risk? [y/N]: " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_error "Installation aborted by user"
        exit 1
    else
        log_warning "Proceeding with installation despite failed checks..."
        echo ""
    fi
fi

log_success "Preflight checks completed"
