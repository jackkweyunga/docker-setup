#!/bin/bash

# Enable error handling
set -e

# Default settings
INSTALL_MODE="remote"
VERSION="latest"  # Will be resolved to actual version number
REPO="jackkweyunga/docker-setup"

# Print help
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Install the Docker Setup Tool (Bash script)

Options:
    --dev                  Install from current directory (development mode)
    --version VERSION      Specify version to install (remote mode only)
    -h, --help             Show this help message
    
Examples:
    $0                     # Install latest release from GitHub
    $0 --version 1.1.2     # Install specific version from GitHub
    $0 --dev               # Install from current directory
EOF
}

# Print a formatted message
say() {
    echo "===> $1"
}

# Cleanup function for error handling
cleanup() {
    if [ -d "$TEMP_DIR" ] && [ "$INSTALL_MODE" = "remote" ]; then
        rm -rf "$TEMP_DIR"
    fi
}

# Set up error handling
trap cleanup EXIT

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dev)
            INSTALL_MODE="dev"
            shift
            ;;
        --version)
            if [ -n "$2" ]; then
                VERSION="$2"
                shift 2
            else
                echo "Error: --version requires an argument"
                exit 1
            fi
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Show banner with mode
if [ "$INSTALL_MODE" = "dev" ]; then
    say "Starting Docker Setup Tool installation (Development Mode)"
else
    if [ "$VERSION" = "latest" ]; then
        say "Starting Docker Setup Tool installation (latest version)"
    else
        say "Starting Docker Setup Tool installation (v${VERSION})"
    fi
fi

# Create installation directories
say "Creating installation directories..."
sudo mkdir -p /usr/local/bin
sudo mkdir -p /etc/docker-setup
sudo mkdir -p /etc/docker-setup/traefik
sudo mkdir -p /etc/docker-setup/traefik/certs
sudo touch /etc/docker-setup/traefik/certs/acme.json
sudo chmod 600 /etc/docker-setup/traefik/certs/acme.json

if [ "$INSTALL_MODE" = "remote" ]; then
    # Remote installation - download from GitHub
    
    # If version is "latest", get the actual latest version number
    if [ "$VERSION" = "latest" ]; then
        say "Determining latest version..."
        LATEST_VERSION=$(curl -s "https://api.github.com/repos/${REPO}/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
        
        if [ -z "$LATEST_VERSION" ]; then
            echo "Error: Failed to determine latest version"
            exit 1
        fi
        
        VERSION="$LATEST_VERSION"
        say "Latest version is v${VERSION}"
    fi
    
    DOWNLOAD_URL="https://github.com/${REPO}/releases/download/v${VERSION}"
    PACKAGE_NAME="docker-setup-${VERSION}"
    
    # Create temporary directory for downloads
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    say "Downloading package (v${VERSION})..."
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
    
    # Install components
    sudo cp bin/docker-setup /usr/local/bin/docker-setup
    sudo cp -r config/* /etc/docker-setup/
    sudo chmod +x /usr/local/bin/docker-setup
    
else
    # Dev installation - copy from current directory
    say "Installing from current directory..."
    
    # Check if we're in the right directory
    if [ ! -f "src/docker-setup.sh" ] && [ ! -f "docker-setup" ]; then
        echo "Error: Could not find docker-setup.sh or docker-setup in current directory"
        echo "Make sure you're in the root directory of the docker-setup project"
        exit 1
    fi
    
    # Install binary
    if [ -f "src/docker-setup.sh" ]; then
        say "Installing Bash script..."
        sudo cp src/docker-setup.sh /usr/local/bin/docker-setup
        sudo chmod +x /usr/local/bin/docker-setup
    elif [ -f "docker-setup" ]; then
        say "Installing script..."
        sudo cp docker-setup /usr/local/bin/
        sudo chmod +x /usr/local/bin/docker-setup
    else
        echo "Error: Could not find docker-setup.sh in current directory"
        echo "Make sure you're in the root directory of the docker-setup project"
        exit 1
    fi
    
    # Copy configuration files
    say "Copying configuration files..."
    if [ -d "templates" ]; then
        sudo cp -r templates/* /etc/docker-setup/
    elif [ -d "config" ]; then
        sudo cp -r config/* /etc/docker-setup/
    else
        echo "Warning: Could not find templates or config directory"
        echo "You may need to manually copy configuration files to /etc/docker-setup/"
    fi
fi

say "Installation completed successfully!"
say "Run 'sudo docker-setup' to begin setting up your Docker infrastructure."