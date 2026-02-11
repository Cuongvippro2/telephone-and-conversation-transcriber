#!/bin/bash
# Caption watchdog - ensures caption service is always running
# Change YOUR_USERNAME to the user running the caption service

if ! sudo -u YOUR_USERNAME XDG_RUNTIME_DIR=/run/user/1000 systemctl --user is-active --quiet caption; then
    echo "$(date): Caption service not running, restarting..." >> /var/log/caption-watchdog.log
    sudo -u YOUR_USERNAME XDG_RUNTIME_DIR=/run/user/1000 systemctl --user restart caption
fi
