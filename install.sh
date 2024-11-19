#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Check if main.rs and nfd.conf are present
if [[ ! -f "src/main.rs" ]] || [[ ! -f "nfd.conf" ]]; then
    echo "Error: Both main.rs and nfd.conf must be present."
    exit 1
fi

# Variables
SERVICE_FILE="/lib/systemd/system/nfd.service"
CONFIG_FILE="/etc/ndn/nfd.conf"
RUST_BINARY="nfd_log"
BUILD_PATH="target/release/$RUST_BINARY"
INSTALL_PATH="/usr/bin/$RUST_BINARY"

# Build the Rust binary
echo "Building nfd_log..."
cargo build --release

# Update the systemd service file
echo "Modifying $SERVICE_FILE..."
sudo sed -i.bak \
    -e 's#^ExecStart=.*#ExecStart=/bin/sh -c "/usr/bin/nfd start --config /etc/ndn/nfd.conf 2>\&1 >/dev/null | /usr/bin/nfd_log"#' \
    -e 's|^PrivateTmp=.*|PrivateTmp=no|' \
    "$SERVICE_FILE"

# Reloading system daemon
echo "Reloading system daemon..."
sudo systemctl daemon-reload

# Replace the configuration file
echo "Replacing $CONFIG_FILE..."
sudo cp nfd.conf "$CONFIG_FILE"

# Stop the NFD service
echo "Stopping NFD service..."
sudo systemctl stop nfd.service

# Install the binary
echo "Installing $RUST_BINARY to $INSTALL_PATH..."
sudo cp "$BUILD_PATH" "$INSTALL_PATH"

# Restarting the systemd service
echo "Restarting NFD service..."
sudo systemctl restart nfd.service

# Clean up build directory
echo "Cleaning up..."
rm -r target

echo "Setup complete!"