#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Check if main.rs and nfd.conf are present
if [[ ! -f "src/bin/nfd_log.rs" ]] || [[ ! -f "nfd.conf" ]]; then
    echo "Error: Both main.rs and nfd.conf must be present."
    exit 1
fi

# Variables
SERVICE_FILE="/lib/systemd/system/nfd.service"
CONFIG_FILE="/etc/ndn/nfd.conf"
LOG_BINARY="nfd_log"
READ_BINARY="nfd_read"
BUILD_PATH="target/release/"
NFD_LOG_X86_DOWNLOAD_URL="https://github.com/Quarmire/nfd-log/releases/download/all/nfd_log_x86_64"
NFD_LOG_AARCH64_DOWNLOAD_URL="https://github.com/Quarmire/nfd-log/releases/download/all/nfd_log_aarch64"
NFD_READ_X86_DOWNLOAD_URL="https://github.com/Quarmire/nfd-log/releases/download/all/nfd_read_x86_64"
NFD_READ_AARCH64_DOWNLOAD_URL="https://github.com/Quarmire/nfd-log/releases/download/all/nfd_read_aarch64"
INSTALL_PATH="/usr/bin/"

compile_binaries() {
    # Build the Rust binary
    echo "Building nfd_log and nfd_read..."
    cargo -q build --release

    # Install binaries to /usr/bin
    echo "Installing $LOG_BINARY to $INSTALL_PATH$LOG_BINARY..."
    sudo cp "$BUILD_PATH$LOG_BINARY" "$INSTALL_PATH$LOG_BINARY"
    echo "Installing $READ_BINARY to $INSTALL_PATH$READ_BINARY..."
    sudo cp "$BUILD_PATH$READ_BINARY" "$INSTALL_PATH$READ_BINARY"

    # Clean up build directory
    echo "Cleaning up..."
    rm -r target
}

# Function to download nfd_log
download_binaries() {
    ARCH=$(uname -m)
    if [ "x86_64" = $ARCH ]
    then
        echo "Downloading binaries for $ARCH architecture..."
        curl -sL "$NFD_LOG_X86_DOWNLOAD_URL" -o ./nfd_log || exit 1
        curl -sL "$NFD_READ_X86_DOWNLOAD_URL" -o ./nfd_read || exit 1
    elif [ "aarch64" = $ARCH ]
    then
        echo "Downloading binaries for $ARCH architecture..."
        curl -sL "$NFD_LOG_AARCH64_DOWNLOAD_URL" -o ./nfd_log || exit 1
        curl -sL "$NFD_READ_AARCH64_DOWNLOAD_URL" -o ./nfd_read || exit 1
    else
        echo "Unsupported architecture: $ARCH"
        exit 1
    fi
    chmod +x "./$LOG_BINARY"
    chmod +x "./$READ_BINARY"
    sudo mv "./$LOG_BINARY" "$INSTALL_PATH$LOG_BINARY"
    sudo mv "./$READ_BINARY" "$INSTALL_PATH$READ_BINARY"
    echo "$INSTALL_PATH$READ_BINARY"
    echo "Downloaded and installed nfd_log and nfd_read."
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
        compile_binaries
        ;;
    download)
        download_binaries
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