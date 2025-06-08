#!/bin/bash

# reMarkable Pro Wallpaper Auto-Changer Script
# This script rotates wallpapers every 4 hours or on wake

# Configuration
WALLPAPER_DIR="/home/root/wallpapers"  # Directory containing your wallpaper images
TARGET_FILE="/usr/share/remarkable/suspended.png"
LOG_FILE="/home/root/wallpaper-changer.log"
INTERVAL_HOURS=4
STATE_FILE="/home/root/.wallpaper_state"  # Tracks last change time

# Function to log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Function to check if enough time has passed
should_change_wallpaper() {
    if [ ! -f "$STATE_FILE" ]; then
        return 0  # First run, should change
    fi
    
    last_change=$(cat "$STATE_FILE" 2>/dev/null || echo 0)
    current_time=$(date +%s)
    hours_passed=$(( (current_time - last_change) / 3600 ))
    
    if [ $hours_passed -ge $INTERVAL_HOURS ]; then
        return 0  # Should change
    else
        return 1  # Too soon
    fi
}

# Function to change wallpaper
change_wallpaper() {
    # Check if wallpaper directory exists
    if [ ! -d "$WALLPAPER_DIR" ]; then
        log_message "ERROR: Wallpaper directory $WALLPAPER_DIR does not exist"
        exit 1
    fi
    
    # Get list of PNG files
    wallpapers=("$WALLPAPER_DIR"/*.png)
    
    # Check if any wallpapers exist
    if [ ${#wallpapers[@]} -eq 0 ] || [ ! -f "${wallpapers[0]}" ]; then
        log_message "ERROR: No PNG files found in $WALLPAPER_DIR"
        exit 1
    fi
    
    # Get current wallpaper index from state file
    INDEX_FILE="/home/root/.wallpaper_index"
    if [ -f "$INDEX_FILE" ]; then
        current_index=$(cat "$INDEX_FILE")
    else
        current_index=0
    fi
    
    # Calculate next index
    next_index=$(( (current_index + 1) % ${#wallpapers[@]} ))
    
    # Copy the wallpaper
    if cp "${wallpapers[$next_index]}" "$TARGET_FILE"; then
        log_message "Changed wallpaper to: ${wallpapers[$next_index]}"
        echo "$next_index" > "$INDEX_FILE"
        date +%s > "$STATE_FILE"  # Update last change time
        
        # Restart xochitl to apply the change
        #systemctl restart xochitl
        #log_message "Restarted xochitl to apply wallpaper change"
    else
        log_message "ERROR: Failed to copy wallpaper"
        exit 1
    fi
}

# Function for conditional wallpaper change
conditional_change() {
    if should_change_wallpaper; then
        hours_since=$(( ($(date +%s) - $(cat "$STATE_FILE" 2>/dev/null || echo 0)) / 3600 ))
        log_message "Checking wallpaper change: $hours_since hours since last change"
        change_wallpaper
    else
        hours_since=$(( ($(date +%s) - $(cat "$STATE_FILE" 2>/dev/null || echo 0)) / 3600 ))
        log_message "Skipping wallpaper change: only $hours_since hours since last change"
    fi
}

# Main execution
case "$1" in
    "install")
        echo "Installing wallpaper changer with wake detection..."
        
        # Create wallpaper directory if it doesn't exist
        mkdir -p "$WALLPAPER_DIR"
        
        # Create main service file
        cat > /etc/systemd/system/wallpaper-changer.service << EOF
[Unit]
Description=reMarkable Wallpaper Changer
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/home/root/wallpaper-changer.sh check
EOF

        # Create timer file (runs hourly to catch up if device was sleeping)
        cat > /etc/systemd/system/wallpaper-changer.timer << EOF
[Unit]
Description=Run Wallpaper Changer hourly

[Timer]
OnCalendar=hourly
OnActiveSec=1h
OnBootSec=5min
OnUnitActiveSec=1h
AccuracySec=5min
Persistent=true
Unit=wallpaper-changer.service

[Install]
WantedBy=timers.target
EOF

        # Create wake detection service
        cat > /etc/systemd/system/wallpaper-wake.service << EOF
[Unit]
Description=Change wallpaper on wake
After=suspend.target

[Service]
Type=oneshot
ExecStart=/home/root/wallpaper-changer.sh wake

[Install]
WantedBy=suspend.target
EOF

        # Create boot service
        cat > /etc/systemd/system/wallpaper-boot.service << EOF
[Unit]
Description=Change wallpaper on boot
After=xochitl.service

[Service]
Type=oneshot
ExecStartPre=/bin/sleep 10
ExecStart=/home/root/wallpaper-changer.sh boot

[Install]
WantedBy=multi-user.target
EOF

        # Copy this script to the proper location
        cp "$0" /home/root/wallpaper-changer.sh
        chmod +x /home/root/wallpaper-changer.sh
        
        # Enable and start all services
        systemctl daemon-reload
        systemctl enable wallpaper-changer.timer
        systemctl enable wallpaper-wake.service
        systemctl enable wallpaper-boot.service
        systemctl start wallpaper-changer.timer
        
        echo "Installation complete!"
        echo "Wallpaper will change:"
        echo "  - Every $INTERVAL_HOURS hours while device is awake"
        echo "  - When device wakes from sleep (if $INTERVAL_HOURS+ hours have passed)"
        echo "  - When device boots (if $INTERVAL_HOURS+ hours have passed)"
        echo ""
        echo "Place your PNG wallpapers in: $WALLPAPER_DIR"
        echo "Check status with: systemctl status wallpaper-changer.timer"
        echo "View logs with: tail -f $LOG_FILE"
        ;;
        
    "uninstall")
        echo "Uninstalling wallpaper changer..."
        systemctl stop wallpaper-changer.timer
        systemctl stop wallpaper-wake.service
        systemctl stop wallpaper-boot.service
        systemctl disable wallpaper-changer.timer
        systemctl disable wallpaper-wake.service
        systemctl disable wallpaper-boot.service
        rm -f /etc/systemd/system/wallpaper-changer.service
        rm -f /etc/systemd/system/wallpaper-changer.timer
        rm -f /etc/systemd/system/wallpaper-wake.service
        rm -f /etc/systemd/system/wallpaper-boot.service
        systemctl daemon-reload
        echo "Uninstalled successfully"
        ;;
        
    "run")
        # Force change without checking time
        change_wallpaper
        ;;
        
    "check")
        # Change only if enough time has passed
        conditional_change
        ;;
        
    "wake")
        log_message "Device woke from sleep - checking wallpaper"
        conditional_change
        ;;
        
    "boot")
        log_message "Device booted - checking wallpaper"
        conditional_change
        ;;
        
    "test")
        echo "Testing wallpaper change..."
        change_wallpaper
        echo "Test complete. Check $LOG_FILE for details."
        ;;
        
    "status")
        echo "=== Wallpaper Changer Status ==="
        echo ""
        if [ -f "$STATE_FILE" ]; then
            last_change=$(cat "$STATE_FILE")
            last_date=$(date -d "@$last_change" '+%Y-%m-%d %H:%M:%S')
            current_time=$(date +%s)
            hours_passed=$(( (current_time - last_change) / 3600 ))
            echo "Last wallpaper change: $last_date ($hours_passed hours ago)"
            echo "Next change due: After $INTERVAL_HOURS hours ($(( INTERVAL_HOURS - hours_passed )) hours remaining)"
        else
            echo "No wallpaper changes recorded yet"
        fi
        echo ""
        echo "Timer status:"
        systemctl status wallpaper-changer.timer --no-pager | grep -E "(Active:|Trigger:)"
        echo ""
        echo "Recent log entries:"
        tail -5 "$LOG_FILE"
        ;;
        
    *)
        echo "Usage: $0 {install|uninstall|run|check|test|status}"
        echo ""
        echo "  install   - Install the wallpaper changer with wake detection"
        echo "  uninstall - Remove the wallpaper changer service"
        echo "  run       - Force wallpaper change immediately"
        echo "  check     - Change wallpaper only if enough time has passed"
        echo "  test      - Test wallpaper change (same as run)"
        echo "  status    - Show current status and last change time"
        exit 1
        ;;
esac