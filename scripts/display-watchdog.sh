#!/bin/bash
# Display watchdog - ensures LightDM is always running

if ! systemctl is-active --quiet lightdm; then
    echo "$(date): LightDM not running, restarting..." >> /var/log/display-watchdog.log
    systemctl restart lightdm
    sleep 5
    if ! systemctl is-active --quiet lightdm; then
        echo "$(date): LightDM still failed, rebooting..." >> /var/log/display-watchdog.log
        reboot
    fi
fi
