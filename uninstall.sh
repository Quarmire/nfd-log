#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Variables
SERVICE_FILE="/lib/systemd/system/nfd.service"
CONFIG_FILE="/etc/ndn/nfd.conf"
ORIG_CONFIG_FILE="/etc/ndn/nfd.conf.sample"
LOG_BINARY="nfd_log"
READ_BINARY="nfd_read"
LOG_INSTALL_PATH="/usr/bin/$LOG_BINARY"
READ_INSTALL_PATH="/usr/bin/$READ_BINARY"

# Update the systemd service file
update_service_file() {
    echo "Modifying $SERVICE_FILE..."
    sudo sed -i.bak \
        -e 's#^ExecStart=.*#ExecStart=/usr/bin/nfd start --config /etc/ndn/nfd.conf#' \
        -e 's|^PrivateTmp=.*|PrivateTmp=yes|' \
        "$SERVICE_FILE"
    
    # Reloading system daemon
    echo "Reloading system daemon..."
    sudo systemctl daemon-reload
}

# Replace the configuration file
restore_nfd_conf() {
    echo "Restoring default NFD config..."
    sudo cp "$ORIG_CONFIG_FILE" "$CONFIG_FILE"
}

# Remove nfd_log from /usr/bin
remove_nfd_log() {
    echo "Removing nfd_log..."
    sudo rm "$LOG_INSTALL_PATH"
    echo "Removing nfd_read..."
    sudo rm "$READ_INSTALL_PATH"
}

# Stop the NFD service
echo "Stopping NFD service..."
sudo systemctl stop nfd.service

update_service_file
restore_nfd_conf
remove_nfd_log

# Restarting the systemd service
echo "Restarting NFD service..."
sudo systemctl restart nfd.service

echo "Uninstallation completed!"