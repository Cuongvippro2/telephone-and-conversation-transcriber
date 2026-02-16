#!/bin/bash
# caption-monitor.sh — Monitors caption service health and sends alerts
# Runs via systemd timer every 5 minutes
#
# Alert method: Uses Home Assistant notify service if HA_TOKEN is available
# in credentials.py. Customize the send_alert function for other methods
# (email, Pushover, ntfy.sh, etc.)

ALERT_COOLDOWN_FILE="/tmp/caption_alert_cooldown"
COOLDOWN_SECONDS=3600  # Don't send more than one alert per hour
LOG_FILE="$HOME/caption.log"
HA_URL="http://localhost:8123"

# Try to read HA token from credentials.py
HA_TOKEN=$(python3 -c "exec(open('$HOME/gramps-transcriber/credentials.py').read()); print(HA_TOKEN)" 2>/dev/null)

send_alert() {
    local title="$1"
    local message="$2"

    # Check cooldown
    if [ -f "$ALERT_COOLDOWN_FILE" ]; then
        last_alert=$(cat "$ALERT_COOLDOWN_FILE")
        now=$(date +%s)
        elapsed=$((now - last_alert))
        if [ "$elapsed" -lt "$COOLDOWN_SECONDS" ]; then
            echo "$(date): Alert suppressed (cooldown: ${elapsed}s/${COOLDOWN_SECONDS}s)"
            return 0
        fi
    fi

    echo "$(date): SENDING ALERT - $title"

    # Send via Home Assistant (if configured)
    if [ -n "$HA_TOKEN" ]; then
        # Change notify/email_family to your HA notify service name
        curl -s -X POST \
            -H "Authorization: Bearer $HA_TOKEN" \
            -H "Content-Type: application/json" \
            -d "{\"message\": \"$message\", \"title\": \"$title\"}" \
            "$HA_URL/api/services/notify/persistent_notification" > /dev/null 2>&1
    fi

    # Update cooldown
    date +%s > "$ALERT_COOLDOWN_FILE"
}

# Check 1: Is the service running?
if ! systemctl --user is-active --quiet caption.service; then
    send_alert \
        "Gramps Transcriber DOWN" \
        "The caption service has stopped. Attempting restart..."
    systemctl --user restart caption.service
    exit 0
fi

# Check 2: Is there a restart loop? (5+ restarts in recent logs)
if [ -f "$LOG_FILE" ]; then
    recent_restarts=$(tail -100 "$LOG_FILE" | grep -c "scheduling restart\|Thread dead, restarting\|Health check.*restarting")
    if [ "$recent_restarts" -ge 5 ]; then
        send_alert \
            "Gramps Transcriber RESTART LOOP" \
            "The transcriber is stuck in a restart loop ($recent_restarts restarts in recent logs). Check caption.log on the Pi."
        exit 0
    fi
fi

# Check 3: Is there an active arecord process? (audio capture working)
if ! pgrep -f "arecord.*hw:" > /dev/null 2>&1; then
    send_alert \
        "Gramps Transcriber NO AUDIO" \
        "No arecord process found - audio capture may have stopped."
    exit 0
fi

# Check 4: Has the log file been updated in the last 10 minutes?
if [ -f "$LOG_FILE" ]; then
    log_age=$(( $(date +%s) - $(stat -c %Y "$LOG_FILE" 2>/dev/null || stat -f %m "$LOG_FILE" 2>/dev/null) ))
    if [ "$log_age" -gt 600 ]; then
        send_alert \
            "Gramps Transcriber STALE" \
            "The log file has not been updated in ${log_age} seconds. The transcriber may be frozen."
        exit 0
    fi
fi

echo "$(date): Caption service healthy"
