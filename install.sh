#!/bin/bash

# Detect OS and architecture
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

# Set version
VERSION="1.0.0"
REPO="jackkweyunga/docker-setup"

echo "Downloading docker-setup ${VERSION}..."
DOWNLOAD_URL="https://github.com/${REPO}/releases/download/v${VERSION}/docker-setup-${VERSION}.tar.gz"

# Download package
curl -L "${DOWNLOAD_URL}" -o docker-setup.tar.gz

# Verify checksum
curl -L "${DOWNLOAD_URL}.sha256" -o docker-setup.sha256
sha256sum -c docker-setup.sha256

# Install
sudo tar -C /usr/local -xzf docker-setup.tar.gz

echo "Installation complete! Run 'docker-setup' to get started."
