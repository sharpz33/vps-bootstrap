#!/bin/bash
set -euo pipefail

# Monitoring Setup - Disk alerts and health checks

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

log "Starting monitoring setup..."

# Check if Discord webhook is provided
DISCORD_WEBHOOK="${DISCORD_WEBHOOK:-}"

if [ -z "$DISCORD_WEBHOOK" ]; then
    log "WARNING: DISCORD_WEBHOOK not set. Monitoring will be installed but notifications disabled."
    log "To enable Discord notifications, set DISCORD_WEBHOOK environment variable."
else
    log "Discord webhook configured"
fi

# Create monitoring directory
MONITOR_DIR="/opt/monitoring"
mkdir -p "$MONITOR_DIR"

# Create health check script
log "Creating health check script..."
cat > "$MONITOR_DIR/health-check.sh" <<'HEALTHEOF'
#!/bin/bash

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

DISCORD_WEBHOOK="${DISCORD_WEBHOOK:-}"
HOSTNAME=$(hostname)

if [ -z "$DISCORD_WEBHOOK" ]; then
    echo "ERROR: DISCORD_WEBHOOK not set"
    echo "Set it with: export DISCORD_WEBHOOK='your-webhook-url'"
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

# Create cron file
cat > /etc/cron.d/vps-monitoring <<CRONEOF
# VPS Monitoring - Health checks and alerts
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
DISCORD_WEBHOOK=${DISCORD_WEBHOOK}

# Health check every hour
0 * * * * root $MONITOR_DIR/health-check.sh >> /var/log/monitoring.log 2>&1

# Disk space check every 6 hours
0 */6 * * * root $MONITOR_DIR/disk-alert.sh >> /var/log/monitoring.log 2>&1
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
    log "⚠️ Discord notifications DISABLED (webhook not provided)"
    log "To enable, set DISCORD_WEBHOOK in /etc/cron.d/vps-monitoring"
else
    log ""
    log "✓ Discord notifications ENABLED"
    log "Test with: $MONITOR_DIR/test-notification.sh"
fi
