#!/bin/bash
# Check if can ping gateway, restart WiFi if not
# Change 192.168.1.1 to your gateway address
if ! ping -c 1 -W 5 192.168.1.1 > /dev/null 2>&1; then
    echo "$(date): Network down, restarting wlan0" >> /var/log/network-watchdog.log
    nmcli radio wifi off && sleep 2 && nmcli radio wifi on
fi
