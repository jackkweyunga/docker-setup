#!/bin/bash

# Enable error handling and command printing
set -e

# Determine latest version if none specified
VERSION="${1:-1.0.69}"
REPO="jackkweyunga/docker-setup"
DOWNLOAD_URL="https://github.com/${REPO}/releases/download/v${VERSION}"
PACKAGE_NAME="docker-setup-${VERSION}"

# Print a formatted message
say() {
    echo "===> $1"
}

# Cleanup function for error handling
cleanup() {
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}

# Set up error handling
trap cleanup EXIT

say "Starting Docker Setup Tool installation (v${VERSION})"

# Create temporary directory for downloads
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

say "Downloading package..."
if ! curl -fsSL "$DOWNLOAD_URL/${PACKAGE_NAME}.tar.gz" -o "${PACKAGE_NAME}.tar.gz"; then
    echo "Error: Failed to download package"
    exit 1
fi

say "Verifying package integrity..."
if ! curl -fsSL "$DOWNLOAD_URL/${PACKAGE_NAME}.tar.gz.sha256" -o "${PACKAGE_NAME}.sha256"; then
    echo "Error: Failed to download checksum"
    exit 1
fi

if ! sha256sum -c "${PACKAGE_NAME}.sha256"; then
    echo "Error: Package verification failed"
    exit 1
fi

say "Extracting package..."
if ! tar xzf "${PACKAGE_NAME}.tar.gz"; then
    echo "Error: Failed to extract package"
    exit 1
fi

say "Installing Docker Setup Tool..."
cd "${PACKAGE_NAME}"

# Create installation directories
sudo mkdir -p /usr/local/bin
sudo mkdir -p /etc/docker-setup
sudo mkdir -p /usr/local/share/docker-setup

# Install components
sudo cp bin/docker-setup /usr/local/bin/
sudo cp -r config/* /etc/docker-setup/
sudo chmod +x /usr/local/bin/docker-setup

say "Installation completed successfully!"
say "Run 'docker-setup' to begin setting up your Docker infrastructure."

# Return to original directory
cd - > /dev/null
