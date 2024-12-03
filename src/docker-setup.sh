#!/bin/bash

# Enable strict error handling
set -euo pipefail

# Script version
VERSION="1.0.0"

# Function to determine the appropriate configuration directory
get_config_dir() {
    # First, check if CONFIG_DIR is explicitly set in the environment
    if [[ -n "${CONFIG_DIR:-}" ]]; then
        echo "Using explicitly set configuration directory: $CONFIG_DIR" >&2
        echo "$CONFIG_DIR"
        return
    fi

    # System-wide installation
    # In the mean time
    echo "Using system-wide configuration directory: /etc/docker-setup" >&2
    echo "/etc/docker-setup"
    return

    # TODO: Decide whether the approach below is good
    # Check if running as root or with sudo
    # if [[ $EUID -eq 0 ]]; then
    #     # System-wide installation
    #     echo "Using system-wide configuration directory: /etc/docker-setup" >&2
    #     echo "/etc/docker-setup"
    #     return
    # fi

    # If user is running the script normally, use local configuration
    # local user_config_dir="$HOME/.docker-setup"
    # echo "Using user-specific configuration directory: $user_config_dir" >&2
    # echo "$user_config_dir"
}

# Set the configuration directory based on the determination
CONFIG_DIR=$(get_config_dir)
TEMPLATE_DIR="/usr/local/share/docker-setup/templates"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logger function to provide consistent output
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        "INFO")  echo -e "${timestamp} ${GREEN}[INFO]${NC} $message" ;;
        "WARN")  echo -e "${timestamp} ${YELLOW}[WARN]${NC} $message" ;;
        "ERROR") echo -e "${timestamp} ${RED}[ERROR]${NC} $message" ;;
    esac
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install Docker using the official installation script
install_docker() {
    log "INFO" "Installing Docker..."
    
    if curl -fsSL https://get.docker.com -o get-docker.sh; then
        sudo sh get-docker.sh
        sudo usermod -aG docker $USER
        log "INFO" "Docker installation completed. You'll need to log out and back in for group changes to take effect."
        
        read -p "Would you like to restart the shell now to apply docker group changes? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            exec su -l $USER
        fi
    else
        log "ERROR" "Failed to download Docker installation script"
        exit 1
    fi
}

# Function to validate email format
validate_email() {
    local email=$1
    if [[ $email =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
        return 0
    fi
    return 1
}

# Function to check and create required configuration files
check_config_files() {
    local config_dir=$1
    local missing_files=()
    
    # Define required files and directories
    local required_paths=(
        "traefik"
        "traefik/traefik.yml"
        "docker-compose.yml"
    )
    
    # Check each required path
    for path in "${required_paths[@]}"; do
        local full_path="${config_dir}/${path}"
        if [[ ! -e "$full_path" ]]; then
            missing_files+=("$path")
        fi
    done
    
    # Handle missing files
    if (( ${#missing_files[@]} )); then
        log "ERROR" "Missing required files/directories:"
        printf '%s\n' "${missing_files[@]}"
        show_directory_structure
        return 1
    fi
    
    return 0
}

# Function to show expected directory structure
show_directory_structure() {
    log "INFO" "Required directory structure:"
    echo "
    ./
    ├── docker-compose.yml
    └── traefik/
        └── traefik.yml"
}

# Function to handle environment variables
setup_environment() {
    local env_file="${CONFIG_DIR}/.env"
    
    # Load existing environment if available
    if [[ -f "$env_file" ]]; then
        log "INFO" "Loading existing environment variables"
        set -a
        source "$env_file"
        set +a
    fi
    
    # Check if we need to prompt for configuration
    if [[ -z "${PORTAINER_DOMAIN:-}" || -z "${EMAIL:-}" ]]; then
        log "INFO" "Configuring environment variables..."
        
        # Get domain
        read -p "Enter your domain for Portainer (e.g., portainer.example.com): " portainer_domain
        echo "PORTAINER_DOMAIN=$portainer_domain" >> "$env_file"
        
        # Get email with validation
        while true; do
            read -p "Enter your email address for SSL certificates: " email
            if validate_email "$email"; then
                echo "EMAIL=$email" >> "$env_file"
                break
            else
                log "WARN" "Invalid email format. Please try again."
            fi
        done
        
        # Update Traefik configuration
        if [[ -f "${CONFIG_DIR}/traefik/traefik.yml" ]]; then
            sed -i "s/your-email@domain.com/$email/" "${CONFIG_DIR}/traefik/traefik.yml"
        fi
    else
        log "INFO" "Using existing configuration:"
        log "INFO" "Portainer Domain: $PORTAINER_DOMAIN"
        log "INFO" "Email: $EMAIL"
    fi
}

# Main setup function
main() {
    log "INFO" "Starting Docker infrastructure setup v${VERSION}"
    
    # Check Docker installation
    if ! command_exists docker; then
        log "WARN" "Docker not found"
        read -p "Would you like to install Docker now? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            install_docker
        else
            log "ERROR" "Docker is required to continue"
            exit 1
        fi
    fi
    
    # Check configuration
    check_config_files "$CONFIG_DIR" || exit 1
    
    # Setup environment
    setup_environment
    
    # Ensure network exists
    if ! docker network ls | grep -q traefik_network; then
        log "INFO" "Creating traefik_network"
        docker network create traefik_network
    fi
    
    # Start services
    log "INFO" "Starting Docker containers"
    if docker compose up -d; then
        log "INFO" "Setup completed successfully!"
        log "INFO" "Access Portainer at: https://$PORTAINER_DOMAIN"
        log "INFO" "Please allow a few minutes for SSL certificates to be generated"
    else
        log "ERROR" "Failed to start containers. Check the logs for details."
        exit 1
    fi
}

# Run main function
main "$@"