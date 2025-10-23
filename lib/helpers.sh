#!/bin/bash

# VPS Bootstrap Helper Functions
# Logging, error handling, and utility functions

# Global variables
export VPS_LOG_FILE="${VPS_LOG_FILE:-/var/log/vps-bootstrap.log}"
export VPS_START_TIME=""
ERROR_HANDLING=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================================
# Logging Functions
# ============================================================================

# Initialize logging
start_install_log() {
    sudo touch "$VPS_LOG_FILE"
    sudo chmod 666 "$VPS_LOG_FILE"

    export VPS_START_TIME=$(date '+%Y-%m-%d %H:%M:%S')

    echo "=================================================================" | tee -a "$VPS_LOG_FILE"
    echo "VPS Bootstrap Started: $VPS_START_TIME" | tee -a "$VPS_LOG_FILE"
    echo "=================================================================" | tee -a "$VPS_LOG_FILE"
    echo "" | tee -a "$VPS_LOG_FILE"
}

# Finalize logging with summary
stop_install_log() {
    if [[ -n ${VPS_LOG_FILE:-} ]] && [[ -n ${VPS_START_TIME:-} ]]; then
        local VPS_END_TIME=$(date '+%Y-%m-%d %H:%M:%S')

        echo "" >> "$VPS_LOG_FILE"
        echo "=================================================================" >> "$VPS_LOG_FILE"
        echo "VPS Bootstrap Completed: $VPS_END_TIME" >> "$VPS_LOG_FILE"
        echo "=================================================================" >> "$VPS_LOG_FILE"
        echo "" >> "$VPS_LOG_FILE"
        echo "Installation Time Summary:" >> "$VPS_LOG_FILE"

        local START_EPOCH=$(date -d "$VPS_START_TIME" +%s)
        local END_EPOCH=$(date -d "$VPS_END_TIME" +%s)
        local DURATION=$((END_EPOCH - START_EPOCH))

        local MINS=$((DURATION / 60))
        local SECS=$((DURATION % 60))

        echo "Total time: ${MINS}m ${SECS}s" >> "$VPS_LOG_FILE"
        echo "=================================================================" >> "$VPS_LOG_FILE"
    fi
}

# Basic log function with timestamp
log() {
    local message="$1"
    local timestamp="[$(date +'%Y-%m-%d %H:%M:%S')]"
    echo -e "${timestamp} ${message}" | tee -a "$VPS_LOG_FILE"
}

# Log with color (terminal only)
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$VPS_LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$VPS_LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$VPS_LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$VPS_LOG_FILE"
}

# Run a script with full logging
run_logged() {
    local script="$1"
    local script_name=$(basename "$script")

    export CURRENT_SCRIPT="$script"

    log_info "Starting: $script_name"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] === Starting: $script ===" >> "$VPS_LOG_FILE"

    # Run script and capture output to log file
    if bash "$script" >> "$VPS_LOG_FILE" 2>&1; then
        local exit_code=0
        log_success "Completed: $script_name"
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] === Completed: $script ===" >> "$VPS_LOG_FILE"
        echo "" >> "$VPS_LOG_FILE"
    else
        local exit_code=$?
        log_error "Failed: $script_name (exit code: $exit_code)"
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] === Failed: $script (exit code: $exit_code) ===" >> "$VPS_LOG_FILE"
        echo "" >> "$VPS_LOG_FILE"
        return $exit_code
    fi

    unset CURRENT_SCRIPT
    return 0
}

# ============================================================================
# Error Handling Functions
# ============================================================================

# Show last N lines of log
show_log_tail() {
    if [[ -f $VPS_LOG_FILE ]]; then
        echo ""
        echo "=========================================="
        echo "Last 30 lines from log:"
        echo "=========================================="
        tail -n 30 "$VPS_LOG_FILE"
        echo "=========================================="
        echo ""
    fi
}

# Save original stdout and stderr
save_original_outputs() {
    exec 3>&1 4>&2
}

# Restore stdout and stderr
restore_outputs() {
    if [ -e /proc/self/fd/3 ] && [ -e /proc/self/fd/4 ]; then
        exec 1>&3 2>&4
    fi
}

# Main error handler
catch_errors() {
    # Prevent recursive error handling
    if [[ $ERROR_HANDLING == true ]]; then
        return
    else
        ERROR_HANDLING=true
    fi

    local exit_code=$?

    restore_outputs

    echo ""
    log_error "================================================"
    log_error "VPS Bootstrap installation stopped!"
    log_error "================================================"
    echo ""

    if [[ -n ${CURRENT_SCRIPT:-} ]]; then
        log_error "Failed script: $CURRENT_SCRIPT"
    else
        log_error "Failed command: $BASH_COMMAND"
    fi

    log_error "Exit code: $exit_code"
    echo ""

    show_log_tail

    log_info "Full log available at: $VPS_LOG_FILE"
    echo ""

    exit $exit_code
}

# Exit handler
exit_handler() {
    local exit_code=$?

    # Only run error handler if we're exiting with an error and haven't already handled it
    if [[ $exit_code -ne 0 && $ERROR_HANDLING != true ]]; then
        catch_errors
    else
        stop_install_log
    fi
}

# Set up error traps
setup_error_handling() {
    trap catch_errors ERR INT TERM
    trap exit_handler EXIT
    save_original_outputs
}

# ============================================================================
# Utility Functions
# ============================================================================

# Check if running as root
require_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if package is installed (apt)
package_installed() {
    dpkg -l | grep -q "^ii  $1 "
}

# Ask for confirmation
confirm() {
    local prompt="$1"
    local default="${2:-n}"

    if [[ $default == "y" ]]; then
        prompt="$prompt [Y/n]: "
    else
        prompt="$prompt [y/N]: "
    fi

    read -p "$prompt" -n 1 -r
    echo

    if [[ $default == "y" ]]; then
        [[ ! $REPLY =~ ^[Nn]$ ]]
    else
        [[ $REPLY =~ ^[Yy]$ ]]
    fi
}

# ============================================================================
# Export functions for use in subshells
# ============================================================================

export -f log
export -f log_info
export -f log_success
export -f log_warning
export -f log_error
export -f run_logged
export -f command_exists
export -f package_installed
export -f require_root
