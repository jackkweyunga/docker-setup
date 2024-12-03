#!/bin/bash

# Tell the script to be strict about errors
set -euo pipefail

# Store the location of our script, so we can find our config files
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/../config"

# The main function that runs our setup
function main() {
    
    # Run configure script
    source "$SCRIPT_DIR/configure.sh"
    
}

# Run the main function
main