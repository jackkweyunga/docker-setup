#!/bin/bash

#!/usr/bin/env bash

# First, ensure we're running in bash
if [ -z "$BASH_VERSION" ]; then
    echo "This script requires bash to run"
    exit 1
fi

# Script version
VERSION="1.1.0"

# Get usage information and argument parsing
show_usage() {
    cat << EOF
Usage: docker-setup [OPTIONS]

A tool for managing Docker infrastructure setup

Options:
    --portainer-domain DOMAIN   Set the Portainer domain (e.g., portainer.example.com)
    --email EMAIL               Set the email for SSL certificates
    --update                    Update to the latest version
    -h, --help                  Show this help message

Examples:
    docker-setup --portainer-domain portainer.example.com --email admin@example.com
    docker-setup --update
EOF
}

# Function to handle updating the tool to a new version
update_tool() {
    log "INFO" "Checking for updates..."
    
    # Get the latest version from the repository
    local latest_version=$(curl -s https://api.github.com/repos/jackkweyunga/docker-setup/releases/latest | grep -Po '"tag_name": "v\K[^"]*')
    
    if [[ -z "$latest_version" ]]; then
        log "ERROR" "Failed to check for updates"
        exit 1
    fi
    
    if [[ "$VERSION" == "$latest_version" ]]; then
        log "INFO" "You are already running the latest version (${VERSION})"
        exit 0
    fi
    
    log "INFO" "New version available: ${latest_version}"
    log "INFO" "Current version: ${VERSION}"
    
    read -p "Would you like to update? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Download and run the installation script
        curl -fsSL https://raw.githubusercontent.com/jackkweyunga/docker-setup/main/install.sh | bash
        log "INFO" "Update completed successfully!"
        exit 0
    fi
}

# Function to update configuration values
update_config() {
    local key=$1
    local value=$2
    local env_file="${CONFIG_DIR}/.env"
    
    # Create .env file if it doesn't exist
    touch "$env_file"
    
    # Update the value in .env file
    if grep -q "^${key}=" "$env_file"; then
        sed -i "s|^${key}=.*|${key}=${value}|" "$env_file"
    else
        echo "${key}=${value}" >> "$env_file"
    fi
    
    log "INFO" "Updated ${key} to: ${value}"
    
    # If updating email, also update traefik configuration
    if [[ "$key" == "EMAIL" ]]; then
        if [[ -f "${CONFIG_DIR}/traefik/traefik.yml" ]]; then
            sed -i "s|email: .*|email: \"${value}\"|" "${CONFIG_DIR}/traefik/traefik.yml"
            log "INFO" "Updated email in Traefik configuration"
        fi
    fi
}


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

        # Load existing environment if available
        log "INFO" "Loading existing environment variables"
        source "$env_file"

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

    run_docker_compose() {
        # Store the current directory
        local original_dir=$(pwd)
        
        # Change to the configuration directory
        cd "${CONFIG_DIR}"
        
        log "INFO" "Running Docker Compose from ${CONFIG_DIR}"
        
        # Run docker compose with proper error handling
        if docker compose up -d; then
            local status=$?
            cd "${original_dir}"  # Return to original directory
            return $status
        else
            local status=$?
            cd "${original_dir}"  # Return to original directory
            return $status
        fi
    }
    
    # Start services
    log "INFO" "Starting Docker containers"
    if run_docker_compose; then
        log "INFO" "Setup completed successfully!"
        log "INFO" "Access Portainer at: https://$PORTAINER_DOMAIN"
        log "INFO" "Please allow a few minutes for SSL certificates to be generated"
    else
        log "ERROR" "Failed to start containers. Check the logs for details."
        exit 1
    fi
}

# Initialize flags to track if we've handled any commands
HANDLED_COMMAND=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --portainer-domain)
            if [[ -n "${2:-}" ]]; then
                update_config "PORTAINER_DOMAIN" "$2"
                HANDLED_COMMAND=true
                shift 2
            else
                log "ERROR" "Missing domain value for --portainer-domain"
                exit 1
            fi
            ;;
        --email)
            if [[ -n "${2:-}" ]]; then
                if validate_email "$2"; then
                    update_config "EMAIL" "$2"
                    HANDLED_COMMAND=true
                    shift 2
                else
                    log "ERROR" "Invalid email format"
                    exit 1
                fi
            else
                log "ERROR" "Missing email value for --email"
                exit 1
            fi
            ;;
        --update)
            update_tool
            HANDLED_COMMAND=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            if [[ "$1" == -* ]]; then
                log "ERROR" "Unknown option: $1"
                show_usage
                exit 1
            fi
            break
            ;;
    esac
done

# Only run main if no other commands were handled
if ! $HANDLED_COMMAND; then
    main "$@"
fi