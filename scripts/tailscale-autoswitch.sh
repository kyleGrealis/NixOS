#!/usr/bin/env bash
KNOWN_NETS=("Go_Canes" "Canes_guest")
LOG_FILE="/var/log/tailscale-autoswitch.log"

log() {
    echo "$(date): $*" >> "$LOG_FILE"
}

get_current_ssid() {
    for iface in /sys/class/net/*/; do
        iface_name=$(basename "$iface")
        if [ -d "/sys/class/net/$iface_name/wireless" ]; then
            if ip addr show "$iface_name" | grep -q "inet " && \
               [ "$(cat "/sys/class/net/$iface_name/operstate")" = "up" ]; then
                ssid=$(iw dev "$iface_name" link | grep "SSID:" | sed 's/.*SSID: //')
                if [ -n "$ssid" ]; then
                    echo "$ssid"
                    return 0
                fi
            fi
        fi
    done
    return 1
}

log "Network change detected"
CURRENT_SSID=$(get_current_ssid || true)

if [ -n "$CURRENT_SSID" ]; then
    log "Connected to SSID: $CURRENT_SSID"
    KNOWN=false
    for NETWORK in "${KNOWN_NETS[@]}"; do
        if [ "$CURRENT_SSID" = "$NETWORK" ]; then
            KNOWN=true
            break
        fi
    done

    if [ "$KNOWN" = true ]; then
        log "Home network detected: $CURRENT_SSID. Running home script..."
        tailscale-home >> "$LOG_FILE" 2>&1
    else
        log "Unknown network detected: $CURRENT_SSID. Running protect script..."
        tailscale-protect >> "$LOG_FILE" 2>&1
    fi
else
    log "No active WiFi connection found"
fi
