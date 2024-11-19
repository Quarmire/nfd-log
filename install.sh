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
NFD_LOG_X86_DOWNLOAD_URL="https://github.com/Quarmire/releases/download/all/nfd_log_x86"
NFD_LOG_AARCH64_DOWNLOAD_URL="https://github.com/Quarmire/releases/download/all/nfd_log_aarch64"
INSTALL_PATH="/usr/bin/$RUST_BINARY"

compile_nfd_log() {
    # Build the Rust binary
    echo "Building nfd_log..."
    cargo build --release

    # Install binary to /usr/bin
    echo "Installing $RUST_BINARY to $INSTALL_PATH..."
    sudo cp "$BUILD_PATH" "$INSTALL_PATH"

    # Clean up build directory
    echo "Cleaning up..."
    rm -r target
}

# Function to download nfd_log
download_nfd_log() {
    ARCH=$(uname -m)
    if [ "x86_64" = $ARCH ]
    then
        echo "Downloading nfd_log binary for $ARCH architecture..."
        curl -L "$NFD_LOG_X86_DOWNLOAD_URL" -o ./nfd_log || exit 1
    elif [ "aarch64" = $ARCH ]
    then
        echo "Downloading nfd_log binary for $ARCH architecture..."
        curl -L "$NFD_LOG_AARCH64_DOWNLOAD_URL" -o ./nfd_log || exit 1
    else
        echo "Unsupported architecture: $ARCH"
        exit 1
    fi
    sudo chmod +x "$RUST_BINARY"
    sudo mv ./nfd_log "$INSTALL_PATH"
    echo "Downloaded and installed nfd_log to $INSTALL_PATH."
}

# Update the systemd service file
update_service_file() {
    echo "Modifying $SERVICE_FILE..."
    sudo sed -i.bak \
        -e 's#^ExecStart=.*#ExecStart=/bin/sh -c "/usr/bin/nfd start --config /etc/ndn/nfd.conf 2>\&1 >/dev/null | /usr/bin/nfd_log"#' \
        -e 's|^PrivateTmp=.*|PrivateTmp=no|' \
        "$SERVICE_FILE"
    
    # Reloading system daemon
    echo "Reloading system daemon..."
    sudo systemctl daemon-reload
}

# Replace the configuration file
replace_nfd_conf() {
    echo "Replacing $CONFIG_FILE..."
    sudo cp nfd.conf "$CONFIG_FILE"
}

# Stop the NFD service
echo "Stopping NFD service..."
sudo systemctl stop nfd.service

case "$1" in
    compile)
        compile_nfd_log
        ;;
    download)
        download_nfd_log
        ;;
    *)
        echo "Usage: $0 {compile|download}"
        exit 1
        ;;
esac

update_service_file
replace_nfd_conf
# Restarting the systemd service
echo "Restarting NFD service..."
sudo systemctl restart nfd.service

echo "Setup completed!"