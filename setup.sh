#!/bin/bash
set -euo pipefail

# VPS Bootstrap - Main Setup Orchestrator
# Ubuntu 24.04 LTS only

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load helper functions (logging, error handling, utilities)
source "$SCRIPT_DIR/lib/helpers.sh"

# Setup error handling (trap ERR, INT, TERM)
setup_error_handling

check_os() {
    if [ ! -f /etc/os-release ]; then
        log_error "Cannot detect OS. /etc/os-release not found."
        exit 1
    fi

    . /etc/os-release

    if [[ "$ID" != "ubuntu" ]]; then
        log_error "Unsupported OS: $ID. This script only supports Ubuntu."
        exit 1
    fi

    if [[ "$VERSION_ID" != "24.04" ]]; then
        log_warning "Detected Ubuntu $VERSION_ID. This script is tested on 24.04 LTS only."
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi

    log_success "OS check passed: Ubuntu $VERSION_ID"
}

main() {
    # Start logging
    start_install_log

    echo ""
    log_info "======================================"
    log_info "VPS Bootstrap - Starting Setup"
    log_info "======================================"
    echo ""

    require_root
    check_os

    echo ""
    log_info "Running preflight checks..."
    echo ""

    # Run preflight checks
    run_logged "$SCRIPT_DIR/scripts/00-preflight.sh"

    echo ""
    log_info "======================================"
    log_info "Starting installation scripts..."
    log_info "======================================"
    echo ""

    # Run setup scripts in order using run_logged
    run_logged "$SCRIPT_DIR/scripts/01-user.sh"
    run_logged "$SCRIPT_DIR/scripts/02-system.sh"
    run_logged "$SCRIPT_DIR/scripts/03-security.sh"
    run_logged "$SCRIPT_DIR/scripts/04-docker.sh"
    run_logged "$SCRIPT_DIR/scripts/05-monitoring.sh"
    run_logged "$SCRIPT_DIR/scripts/06-sops.sh"

    # Stop logging with summary
    stop_install_log

    echo ""
    log_success "======================================"
    log_success "VPS Bootstrap completed successfully!"
    log_success "======================================"
    echo ""
    log_warning "CRITICAL: SSH root login is now DISABLED"
    echo ""
    log_info "Next steps:"
    log_info "1. Test SSH login as new user BEFORE disconnecting root session"
    log_info "   (open new terminal: ssh USERNAME@YOUR_SERVER_IP)"
    log_info "2. Configure Age key: ~/.config/sops/age/keys.txt"
    log_info "3. Test Discord alerts (if webhook provided)"
    log_info "4. Reboot recommended: sudo reboot"
    echo ""
    log_info "Full log file: $VPS_LOG_FILE"
    echo ""
}

main "$@"
