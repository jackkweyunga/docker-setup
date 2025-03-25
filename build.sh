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

# Update the version in the script
# We use a different delimiter (|) because version numbers contain periods
sed -i "s|VERSION=\"[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\"|VERSION=\"${VERSION}\"|" \
    "src/docker-setup.sh"

# Verify the version was updated correctly
if ! grep "VERSION=\"${VERSION}\"" "src/docker-setup.sh" > /dev/null; then
    echo "Error: Failed to update version in script"
    exit 1
fi

echo "Successfully updated script version to ${VERSION}"

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
To install with curl (after publishing):
curl -fsSL https://raw.githubusercontent.com/jackkweyunga/docker-setup/main/install.sh | bash
"