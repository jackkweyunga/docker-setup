#!/usr/bin/env bash

# First, ensure we're running in bash
if [ -z "$BASH_VERSION" ]; then
    echo "This script requires bash to run"
    exit 1
fi

# Enable error handling for safer script execution
set -euo pipefail

# Version of our package - centralize this for easier maintenance
VERSION=$1

# Define our directory structure
DIST_DIR="dist"
PACKAGE_NAME="docker-setup-${VERSION}"

echo "Starting build process for Docker Setup Tool v${VERSION}"

# First, let's create our distribution directory structure
echo "Creating distribution directory structure..."
mkdir -p "${DIST_DIR}/${PACKAGE_NAME}"/{bin,config,doc}

# Copy our main script to the bin directory, making it executable
echo "Preparing main script..."
cp src/docker-setup.sh "${DIST_DIR}/${PACKAGE_NAME}/bin/docker-setup"
chmod +x "${DIST_DIR}/${PACKAGE_NAME}/bin/docker-setup"

# Copy configuration templates and examples
echo "Copying configuration files..."
if [ -d "config" ]; then
    cp -r config/* "${DIST_DIR}/${PACKAGE_NAME}/config/"
else
    echo "Warning: No config directory found. Creating example configurations..."
    # Here you might want to generate example config files if they don't exist
fi

# Copy documentation files
echo "Copying documentation..."
cp README.md LICENSE CONTRIBUTING.md "${DIST_DIR}/${PACKAGE_NAME}/doc/" 2>/dev/null || true

# Create the install script that will help users set up the tool
cat > "${DIST_DIR}/${PACKAGE_NAME}/install.sh" << 'EOF'
#!/bin/bash
# Installation script for Docker Setup Tool

# Default installation locations
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc/docker-setup"
DOC_DIR="/usr/local/share/docker-setup/doc"

# Create necessary directories
sudo mkdir -p "$CONFIG_DIR"
sudo mkdir -p "$DOC_DIR"

# Install the main script
sudo cp bin/docker-setup "$INSTALL_DIR/"
sudo chmod +x "$INSTALL_DIR/docker-setup"

# Copy configuration templates
if [ -d "config" ]; then
    sudo cp -r config/* "$CONFIG_DIR/"
fi

# Copy documentation
if [ -d "doc" ]; then
    sudo cp -r doc/* "$DOC_DIR/"
fi

echo "Installation complete! You can now run 'docker-setup' to begin."
EOF

# Make the install script executable
chmod +x "${DIST_DIR}/${PACKAGE_NAME}/install.sh"

# Create the distribution package
echo "Creating distribution package..."
cd "${DIST_DIR}"
tar -czf "${PACKAGE_NAME}.tar.gz" "${PACKAGE_NAME}"

# Generate a checksum for security verification
sha256sum "${PACKAGE_NAME}.tar.gz" > "${PACKAGE_NAME}.tar.gz.sha256"

# Clean up the temporary directory structure
rm -rf "${PACKAGE_NAME}"

echo "Build complete! Distribution package is ready:"
echo "- Package: ${DIST_DIR}/${PACKAGE_NAME}.tar.gz"
echo "- Checksum: ${DIST_DIR}/${PACKAGE_NAME}.tar.gz.sha256"

# Provide a helpful message about using the package
echo "
To install manually:
1. Extract the archive: tar -xzf ${PACKAGE_NAME}.tar.gz
2. Enter the directory: cd ${PACKAGE_NAME}
3. Run the installer: ./install.sh

To install with curl (after publishing):
curl -fsSL https://your-domain.com/install.sh | bash
"