#!/bin/bash
set -euo pipefail

# Monitoring Setup - Disk alerts and health checks

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

log "Starting monitoring setup..."

# Create monitoring directory first
MONITOR_DIR="/opt/monitoring"
mkdir -p "$MONITOR_DIR"
CONFIG_FILE="$MONITOR_DIR/config"

# Check if Discord webhook is already configured
if [ -f "$CONFIG_FILE" ] && grep -q "DISCORD_WEBHOOK=" "$CONFIG_FILE"; then
    log "Discord webhook already configured (found in $CONFIG_FILE)"
    source "$CONFIG_FILE"
    DISCORD_WEBHOOK="${DISCORD_WEBHOOK:-}"
else
    # Check environment variable
    DISCORD_WEBHOOK="${DISCORD_WEBHOOK:-}"

    if [ -z "$DISCORD_WEBHOOK" ]; then
        log "Discord webhook not configured."
        echo ""
        read -p "Would you like to configure Discord webhook for alerts? [y/N]: " -n 1 -r
        echo

        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "Enter your Discord webhook URL:"
            read -r DISCORD_WEBHOOK

            if [ -n "$DISCORD_WEBHOOK" ]; then
                log "Saving Discord webhook to config..."
                cat > "$CONFIG_FILE" <<EOF
# Monitoring Configuration
DISCORD_WEBHOOK="$DISCORD_WEBHOOK"
EOF
                chmod 600 "$CONFIG_FILE"
                log "Discord webhook configured and saved to $CONFIG_FILE"
            else
                log "No webhook provided. Monitoring will be installed without notifications."
                DISCORD_WEBHOOK=""
            fi
        else
            log "Skipping Discord webhook configuration. Monitoring will be installed without notifications."
            DISCORD_WEBHOOK=""
        fi
    else
        # Webhook from environment - save to config
        log "Saving Discord webhook from environment to config..."
        cat > "$CONFIG_FILE" <<EOF
# Monitoring Configuration
DISCORD_WEBHOOK="$DISCORD_WEBHOOK"
EOF
        chmod 600 "$CONFIG_FILE"
        log "Discord webhook configured"
    fi
fi

# Create health check script
log "Creating health check script..."
cat > "$MONITOR_DIR/health-check.sh" <<'HEALTHEOF'
#!/bin/bash

# Load config
CONFIG_FILE="/opt/monitoring/config"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

DISCORD_WEBHOOK="${DISCORD_WEBHOOK:-}"
HOSTNAME=$(hostname)
DISK_THRESHOLD=85

send_discord() {
    local message="$1"
    if [ -n "$DISCORD_WEBHOOK" ]; then
        curl -s -H "Content-Type: application/json" \
            -d "{\"content\":\"🖥️ **$HOSTNAME**: $message\"}" \
            "$DISCORD_WEBHOOK" > /dev/null
    fi
}

# Check disk space
DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')

if [ "$DISK_USAGE" -ge "$DISK_THRESHOLD" ]; then
    MESSAGE="🚨 ALERT: Disk usage at ${DISK_USAGE}% (threshold: ${DISK_THRESHOLD}%)"
    echo "$MESSAGE"
    send_discord "$MESSAGE"
fi

# Check Docker status
if ! systemctl is-active --quiet docker; then
    MESSAGE="🚨 ALERT: Docker service is not running"
    echo "$MESSAGE"
    send_discord "$MESSAGE"
fi

# Check if any Docker containers are down (if any exist)
if command -v docker &> /dev/null; then
    CONTAINERS_DOWN=$(docker ps -a --filter "status=exited" --format "{{.Names}}" 2>/dev/null || true)
    if [ -n "$CONTAINERS_DOWN" ]; then
        MESSAGE="⚠️ WARNING: Docker containers stopped: $CONTAINERS_DOWN"
        echo "$MESSAGE"
        send_discord "$MESSAGE"
    fi
fi
HEALTHEOF

chmod +x "$MONITOR_DIR/health-check.sh"

# Create disk alert script
log "Creating disk alert script..."
cat > "$MONITOR_DIR/disk-alert.sh" <<'DISKEOF'
#!/bin/bash

# Load config
CONFIG_FILE="/opt/monitoring/config"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

DISCORD_WEBHOOK="${DISCORD_WEBHOOK:-}"
HOSTNAME=$(hostname)
THRESHOLD=85

send_discord() {
    local message="$1"
    if [ -n "$DISCORD_WEBHOOK" ]; then
        curl -s -H "Content-Type: application/json" \
            -d "{\"content\":\"💾 **$HOSTNAME**: $message\"}" \
            "$DISCORD_WEBHOOK" > /dev/null
    fi
}

# Check all mounted filesystems
df -h | awk 'NR>1 {print $5 " " $6}' | while read usage mountpoint; do
    usage_num=$(echo $usage | sed 's/%//')
    if [ "$usage_num" -ge "$THRESHOLD" ]; then
        MESSAGE="🚨 Disk alert: $mountpoint at $usage"
        echo "$MESSAGE"
        send_discord "$MESSAGE"
    fi
done
DISKEOF

chmod +x "$MONITOR_DIR/disk-alert.sh"

# Create test notification script
log "Creating test notification script..."
cat > "$MONITOR_DIR/test-notification.sh" <<'TESTEOF'
#!/bin/bash

# Load config
CONFIG_FILE="/opt/monitoring/config"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

DISCORD_WEBHOOK="${DISCORD_WEBHOOK:-}"
HOSTNAME=$(hostname)

if [ -z "$DISCORD_WEBHOOK" ]; then
    echo "ERROR: DISCORD_WEBHOOK not configured"
    echo ""
    echo "Configure it by editing: $CONFIG_FILE"
    echo "Or set environment variable: export DISCORD_WEBHOOK='your-webhook-url'"
    exit 1
fi

echo "Sending test notification to Discord..."
curl -s -H "Content-Type: application/json" \
    -d "{\"content\":\"✅ **$HOSTNAME**: Monitoring test successful!\"}" \
    "$DISCORD_WEBHOOK"

echo ""
echo "Test notification sent!"
TESTEOF

chmod +x "$MONITOR_DIR/test-notification.sh"

# Set up cron jobs
log "Setting up cron jobs..."

# Create cron file (no need to pass DISCORD_WEBHOOK, scripts read from config)
cat > /etc/cron.d/vps-monitoring <<'CRONEOF'
# VPS Monitoring - Health checks and alerts
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

# Health check every hour
0 * * * * root /opt/monitoring/health-check.sh >> /var/log/monitoring.log 2>&1

# Disk space check every 6 hours
0 */6 * * * root /opt/monitoring/disk-alert.sh >> /var/log/monitoring.log 2>&1
CRONEOF

chmod 644 /etc/cron.d/vps-monitoring

# Create log file
touch /var/log/monitoring.log
chmod 644 /var/log/monitoring.log

log "Monitoring setup completed successfully"
log ""
log "Monitoring scripts installed in: $MONITOR_DIR"
log "  - health-check.sh: Hourly health checks"
log "  - disk-alert.sh: Disk space alerts (every 6h)"
log "  - test-notification.sh: Test Discord notifications"
log ""
log "Cron jobs configured:"
log "  - Health check: every hour"
log "  - Disk alert: every 6 hours"
log ""
log "Log file: /var/log/monitoring.log"

if [ -z "$DISCORD_WEBHOOK" ]; then
    log ""
    log "⚠️  Discord notifications DISABLED (webhook not configured)"
    log "To enable later, edit: $CONFIG_FILE"
    log "Then test with: $MONITOR_DIR/test-notification.sh"
else
    log ""
    log "✓ Discord notifications ENABLED"
    log "Configuration saved to: $CONFIG_FILE"
    log "Test with: $MONITOR_DIR/test-notification.sh"
fi
