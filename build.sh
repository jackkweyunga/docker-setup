#!/bin/bash

# This script builds our binary

# Make sure we have shc installed (shc is what turns our script into a binary)
if ! command -v shc >/dev/null 2>&1; then
    echo "Installing shc (script compiler)..."
    sudo apt-get update
    sudo apt-get install -y shc
fi

# Create the bin directory
echo "Creating the bin directory if not exists"
mkdir -p bin

# Create our binary
echo "Building binary..."
shc -f src/docker-setup.sh -o bin/docker-setup

# Copy our config files
echo "Copying configuration files..."
cp -r config/* bin/

# Create a package
echo "Creating distribution package..."
tar -czf docker-setup.tar.gz bin/*

echo "Build complete! Your binary is ready in docker-setup.tar.gz"