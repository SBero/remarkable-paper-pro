#!/bin/bash

# reMarkable Pro Wallpaper Auto-Changer Script
# This script rotates wallpapers every 4 hours

# Configuration
WALLPAPER_DIR="/home/root/wallpapers"  # Directory containing your wallpaper images
TARGET_FILE="/usr/share/remarkable/suspended.png"
LOG_FILE="/home/root/wallpaper-changer.log"
INTERVAL_HOURS=4

# Function to log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
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
    STATE_FILE="/home/root/.wallpaper_index"
    if [ -f "$STATE_FILE" ]; then
        current_index=$(cat "$STATE_FILE")
    else
        current_index=0
    fi
    
    # Calculate next index
    next_index=$(( (current_index + 1) % ${#wallpapers[@]} ))
    
    # Copy the wallpaper
    if cp "${wallpapers[$next_index]}" "$TARGET_FILE"; then
        log_message "Changed wallpaper to: ${wallpapers[$next_index]}"
        echo "$next_index" > "$STATE_FILE"
        
        # Restart xochitl to apply the change (if needed)
        # Uncomment the following line if the wallpaper doesn't update automatically
        # systemctl restart xochitl
    else
        log_message "ERROR: Failed to copy wallpaper"
        exit 1
    fi
}

# Main execution
case "$1" in
    "install")
        echo "Installing wallpaper changer..."
        
        # Create wallpaper directory if it doesn't exist
        mkdir -p "$WALLPAPER_DIR"
        
        # Create systemd service file
        cat > /etc/systemd/system/wallpaper-changer.service << EOF
[Unit]
Description=reMarkable Wallpaper Changer
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/home/root/wallpaper-changer.sh run
EOF

        # Create systemd timer file
        cat > /etc/systemd/system/wallpaper-changer.timer << EOF
[Unit]
Description=Run Wallpaper Changer every 4 hours
Requires=wallpaper-changer.service

[Timer]
OnBootSec=5min
OnUnitActiveSec=${INTERVAL_HOURS}h
AccuracySec=1min
Persistent=true
AccuracySec=1min
Unit=wallpaper-changer.service

[Install]
WantedBy=timers.target
EOF

        # Copy this script to the proper location
        cp "$0" /home/root/wallpaper-changer.sh
        chmod +x /home/root/wallpaper-changer.sh
        
        # Enable and start the timer
        systemctl daemon-reload
        systemctl enable wallpaper-changer.timer
        systemctl start wallpaper-changer.timer
        
        echo "Installation complete!"
        echo "Place your PNG wallpapers in: $WALLPAPER_DIR"
        echo "Check status with: systemctl status wallpaper-changer.timer"
        ;;
        
    "uninstall")
        echo "Uninstalling wallpaper changer..."
        systemctl stop wallpaper-changer.timer
        systemctl disable wallpaper-changer.timer
        rm -f /etc/systemd/system/wallpaper-changer.service
        rm -f /etc/systemd/system/wallpaper-changer.timer
        systemctl daemon-reload
        echo "Uninstalled successfully"
        ;;
        
    "run")
        change_wallpaper
        ;;
        
    "test")
        echo "Testing wallpaper change..."
        change_wallpaper
        echo "Test complete. Check $LOG_FILE for details."
        ;;
        
    *)
        echo "Usage: $0 {install|uninstall|run|test}"
        echo ""
        echo "  install   - Install the wallpaper changer service"
        echo "  uninstall - Remove the wallpaper changer service"
        echo "  run       - Run the wallpaper changer once"
        echo "  test      - Test the wallpaper changer"
        exit 1
        ;;
esac