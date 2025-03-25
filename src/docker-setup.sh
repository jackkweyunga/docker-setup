#!/bin/bash

#!/usr/bin/env bash

# Function to setup environment for Traefik dashboard
setup_traefik_dashboard() {
    local enable_dashboard="${ENABLE_TRAEFIK_DASHBOARD:-}"
    
    # If not set, ask the user
    if [[ -z "$enable_dashboard" ]]; then
        read -p "Do you want to enable the Traefik dashboard? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            update_config "ENABLE_TRAEFIK_DASHBOARD" "true"
            
            # Ask for dashboard port
            read -p "Enter port for Traefik dashboard [8080]: " dashboard_port
            dashboard_port=${dashboard_port:-8080}
            update_config "TRAEFIK_DASHBOARD_PORT" "$dashboard_port"
        else
            update_config "ENABLE_TRAEFIK_DASHBOARD" "false"
        fi
    fi
    
    # Update Traefik configuration
    update_traefik_dashboard
}
# Function to update Traefik dashboard settings
update_traefik_dashboard() {
    local traefik_config="${CONFIG_DIR}/traefik/traefik.yml"
    
    # Load existing environment variables
    local env_file="${CONFIG_DIR}/.env"
    if [[ -f "$env_file" ]]; then
        source "$env_file"
    fi
    
    # Check if traefik.yml exists
    if [[ ! -f "$traefik_config" ]]; then
        log "ERROR" "Traefik configuration file not found: ${traefik_config}"
        return 1
    fi
    
    # Update dashboard settings based on environment variables
    if [[ "${ENABLE_TRAEFIK_DASHBOARD:-false}" == "true" ]]; then
        # Enable dashboard
        if grep -q "api:" "$traefik_config"; then
            # Update existing api section
            sed -i '/api:/,/insecure:/ s/dashboard: .*/dashboard: true/' "$traefik_config"
            sed -i '/api:/,/insecure:/ s/insecure: .*/insecure: true/' "$traefik_config"
        else
            # Add api section if it doesn't exist
            cat << EOF >> "$traefik_config"

# API and Dashboard configuration
api:
  dashboard: true
  insecure: true
EOF
        fi
        log "INFO" "Traefik dashboard enabled"
    else
        # Disable dashboard
        if grep -q "api:" "$traefik_config"; then
            # Update existing api section
            sed -i '/api:/,/insecure:/ s/dashboard: .*/dashboard: false/' "$traefik_config"
            sed -i '/api:/,/insecure:/ s/insecure: .*/insecure: false/' "$traefik_config"
        fi
        log "INFO" "Traefik dashboard disabled"
    fi
    
    # Update port if specified
    if [[ -n "${TRAEFIK_DASHBOARD_PORT:-}" ]]; then
        log "INFO" "Setting Traefik dashboard port to: ${TRAEFIK_DASHBOARD_PORT}"
    fi
}

# Check for sudo privileges
if [ "$EUID" -ne 0 ]; then
    echo "This script requires sudo privileges. Please run with sudo."
    exit 1
fi

# First, ensure we're running in bash
if [ -z "$BASH_VERSION" ]; then
    echo "This script requires bash to run"
    exit 1
fi

# Script version
VERSION="1.3.1"

# Get usage information and argument parsing
show_usage() {
    cat << EOF
Usage: sudo docker-setup [OPTIONS]

A tool for managing Docker infrastructure setup

Options:
    --enable-portainer          Enable Portainer container management UI
    --disable-portainer         Disable Portainer container management UI
    --portainer-domain DOMAIN   Set the Portainer domain (e.g., portainer.example.com)
    --email EMAIL               Set the email for SSL certificates
    --update                    Update to the latest version
    --enable-dns-challenge      Enable DNS challenge for SSL certificates
    --dns-provider PROVIDER     Set the DNS provider (currently only 'cloudflare' supported)
    --cf-email EMAIL            Set the Cloudflare API email
    --cf-api-token TOKEN        Set the Cloudflare DNS API token
    --enable-traefik-dashboard  Enable Traefik dashboard
    --disable-traefik-dashboard Disable Traefik dashboard
    --traefik-dashboard-port PORT Set the Traefik dashboard port (default: 8080)
    -h, --help                  Show this help message

Examples:
    sudo docker-setup --enable-portainer --portainer-domain portainer.example.com --email admin@example.com
    sudo docker-setup --enable-dns-challenge --dns-provider cloudflare --cf-email user@domain.com --cf-api-token your_token
    sudo docker-setup --enable-traefik-dashboard --traefik-dashboard-port 8080
    sudo docker-setup --update
EOF
}

# Function to update the tool to a new version
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

    # Since we're running as root, use system-wide configuration
    echo "Using system-wide configuration directory: /etc/docker-setup" >&2
    
    # Create the directory if it doesn't exist
    if [[ ! -d "/etc/docker-setup" ]]; then
        mkdir -p /etc/docker-setup
        # If SUDO_USER is set, change ownership to the original user
        if [[ -n "${SUDO_USER:-}" ]]; then
            chown -R $SUDO_USER:$(id -g $SUDO_USER) /etc/docker-setup
        fi
    fi
    
    echo "/etc/docker-setup"
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
        sh get-docker.sh
        usermod -aG docker $SUDO_USER
        log "INFO" "Docker installation completed. You'll need to log out and back in for group changes to take effect."
        
        read -p "Would you like to restart the shell now to apply docker group changes? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            if [ -n "$SUDO_USER" ]; then
                exec su -l $SUDO_USER
            else
                log "WARN" "Unable to determine the original user. Please log out and log back in."
            fi
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

# Function to handle DNS challenge setup
setup_dns_challenge() {
    local env_file="${CONFIG_DIR}/.env"
    local use_dns_challenge="${USE_DNS_CHALLENGE:-}"
    
    # If USE_DNS_CHALLENGE is not set, ask the user
    if [[ -z "$use_dns_challenge" ]]; then
        read -p "Do you want to use DNS challenge for SSL certificate validation? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            update_config "USE_DNS_CHALLENGE" "true"
            select_dns_provider
        else
            update_config "USE_DNS_CHALLENGE" "false"
            log "INFO" "DNS challenge disabled. Using HTTP challenge instead."
        fi
    elif [[ "$use_dns_challenge" == "true" && -z "${DNS_PROVIDER:-}" ]]; then
        # If DNS challenge is enabled but no provider is set
        select_dns_provider
    fi
}

# Function to select DNS provider
select_dns_provider() {
    local provider="${DNS_PROVIDER:-}"
    
    # If provider is already set, confirm or change
    if [[ -n "$provider" ]]; then
        log "INFO" "Current DNS provider: $provider"
        read -p "Do you want to change the DNS provider? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            # Provider remains the same, just validate credentials
            setup_dns_provider_credentials "$provider"
            return
        fi
    fi
    
    # Show available providers
    echo "Available DNS providers:"
    echo "1) Cloudflare"
    # Add more providers here in the future
    
    # Get user selection
    read -p "Select a DNS provider (enter number): " provider_num
    
    case "$provider_num" in
        1)
            update_config "DNS_PROVIDER" "cloudflare"
            setup_dns_provider_credentials "cloudflare"
            ;;
        *)
            log "ERROR" "Invalid selection. Defaulting to HTTP challenge."
            update_config "USE_DNS_CHALLENGE" "false"
            ;;
    esac
}

# Function to set up DNS provider credentials
setup_dns_provider_credentials() {
    local provider=$1
    
    case "$provider" in
        "cloudflare")
            setup_cloudflare_credentials
            ;;
        *)
            log "ERROR" "Unsupported DNS provider: $provider"
            ;;
    esac
}

# Function to set up Cloudflare credentials
setup_cloudflare_credentials() {
    local cf_email="${CF_API_EMAIL:-}"
    local cf_api_token="${CF_DNS_API_TOKEN:-}"
    
    log "INFO" "Setting up Cloudflare DNS credentials"
    
    # Get Cloudflare email if not set
    if [[ -z "$cf_email" ]]; then
        read -p "Enter your Cloudflare account email: " cf_email
        if ! validate_email "$cf_email"; then
            log "ERROR" "Invalid email format"
            setup_cloudflare_credentials
            return
        fi
    else
        log "INFO" "Using existing Cloudflare email: $cf_email"
        read -p "Do you want to change it? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            read -p "Enter your Cloudflare account email: " cf_email
            if ! validate_email "$cf_email"; then
                log "ERROR" "Invalid email format"
                setup_cloudflare_credentials
                return
            fi
        fi
    fi
    
    # Get Cloudflare API token if not set
    if [[ -z "$cf_api_token" ]]; then
        read -p "Enter your Cloudflare DNS API token: " cf_api_token
        if [[ -z "$cf_api_token" ]]; then
            log "ERROR" "API token cannot be empty"
            setup_cloudflare_credentials
            return
        fi
    else
        log "INFO" "Cloudflare API token is already set"
        read -p "Do you want to change it? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            read -p "Enter your Cloudflare DNS API token: " cf_api_token
            if [[ -z "$cf_api_token" ]]; then
                log "ERROR" "API token cannot be empty"
                setup_cloudflare_credentials
                return
            fi
        fi
    fi
    
    # Update configuration
    update_config "CF_API_EMAIL" "$cf_email"
    update_config "CF_DNS_API_TOKEN" "$cf_api_token"
    
    log "INFO" "Cloudflare credentials configured successfully"
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
    if [[ -z "${USE_PORTAINER:-}" || -z "${EMAIL:-}" ]]; then
        log "INFO" "Configuring environment variables..."
        
        # Ask if Portainer should be enabled
        if [[ -z "${USE_PORTAINER:-}" ]]; then
            read -p "Do you want to include Portainer in your setup? (y/n) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                update_config "USE_PORTAINER" "true"
                
                # Only ask for Portainer domain if it's enabled
                if [[ -z "${PORTAINER_DOMAIN:-}" ]]; then
                    read -p "Enter your domain for Portainer (e.g., portainer.example.com): " portainer_domain
                    update_config "PORTAINER_DOMAIN" "$portainer_domain"
                fi
            else
                update_config "USE_PORTAINER" "false"
                log "INFO" "Portainer will not be included in the setup"
            fi
        elif [[ "${USE_PORTAINER}" == "true" && -z "${PORTAINER_DOMAIN:-}" ]]; then
            # If Portainer is enabled but no domain is set
            read -p "Enter your domain for Portainer (e.g., portainer.example.com): " portainer_domain
            update_config "PORTAINER_DOMAIN" "$portainer_domain"
        fi
        
        # Get email with validation if not set
        if [[ -z "${EMAIL:-}" ]]; then
            while true; do
                read -p "Enter your email address for SSL certificates: " email
                if validate_email "$email"; then
                    update_config "EMAIL" "$email"
                    break
                else
                    log "WARN" "Invalid email format. Please try again."
                fi
            done
            
            # Update Traefik configuration
            if [[ -f "${CONFIG_DIR}/traefik/traefik.yml" ]]; then
                sed -i "s/your-email@domain.com/$email/" "${CONFIG_DIR}/traefik/traefik.yml"
                # Also update the existing email in the file
                sed -i "s/akauntiyamchezo@gmail.com/$email/" "${CONFIG_DIR}/traefik/traefik.yml"
                # Update the Cloudflare email placeholder
                sed -i "s/{{ EMAIL }}/$email/" "${CONFIG_DIR}/traefik/traefik.yml"
            fi
        fi

        # Reload environment variables
        if [[ -f "$env_file" ]]; then
            log "INFO" "Loading updated environment variables"
            set -a
            source "$env_file"
            set +a
        fi
    else
        log "INFO" "Using existing configuration:"
        if [[ "${ENABLE_PORTAINER}" == "true" ]]; then
            log "INFO" "Portainer Enabled: Yes"
            log "INFO" "Portainer Domain: ${PORTAINER_DOMAIN:-Not Set}"
        else
            log "INFO" "Portainer Enabled: No"
        fi
        log "INFO" "Email: $EMAIL"
    fi
    
    # Setup Traefik dashboard
    setup_traefik_dashboard
    
    # Setup DNS challenge if needed
    setup_dns_challenge
}

# Function to show current DNS challenge configuration
show_dns_config() {
    local env_file="${CONFIG_DIR}/.env"
    
    # Load .env file if it exists
    if [[ -f "$env_file" ]]; then
        source "$env_file"
    else
        log "ERROR" "Configuration file not found"
        return 1
    fi
    
    # Display DNS challenge configuration
    log "INFO" "DNS Challenge Configuration:"
    echo "DNS Challenge Enabled: ${USE_DNS_CHALLENGE:-false}"
    
    if [[ "${USE_DNS_CHALLENGE:-false}" == "true" ]]; then
        echo "DNS Provider: ${DNS_PROVIDER:-none}"
        
        if [[ "${DNS_PROVIDER:-}" == "cloudflare" ]]; then
            echo "Cloudflare Email: ${CF_API_EMAIL:-not set}"
            echo "Cloudflare API Token: ${CF_DNS_API_TOKEN:+[set]}"
            if [[ -z "${CF_DNS_API_TOKEN:-}" ]]; then
                echo "Cloudflare API Token: not set"
            fi
        fi
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
        # Pass through any additional arguments (like profiles)
        if docker compose $@ up -d; then
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
    
    # Determine which profiles to use
    local profiles=""
    if [[ "${USE_PORTAINER:-false}" == "true" ]]; then
        profiles="--profile portainer"
    fi
    
    if [[ "${ENABLE_TRAEFIK_DASHBOARD:-false}" == "true" ]]; then
        profiles="$profiles --profile ui"
    fi
    
    # Check if we should use Watchtower
    if [[ "${USE_WATCHTOWER:-true}" == "true" ]]; then
        profiles="$profiles --profile maintenance"
    fi
    
    # If no specific profiles, use default
    if [[ -z "$profiles" ]]; then
        log "INFO" "Using default configuration"
    else
        log "INFO" "Using profiles: $profiles"
    fi
    
    if run_docker_compose $profiles; then
        log "INFO" "Setup completed successfully!"
        if [[ "${USE_PORTAINER:-false}" == "true" && -n "${PORTAINER_DOMAIN:-}" ]]; then
            log "INFO" "Access Portainer at: https://$PORTAINER_DOMAIN"
        fi
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
        --enable-portainer)
            update_config "USE_PORTAINER" "true"
            HANDLED_COMMAND=true
            shift
            ;;
        --disable-portainer)
            update_config "USE_PORTAINER" "false"
            HANDLED_COMMAND=true
            shift
            ;;
        --portainer-domain)
            if [[ -n "${2:-}" ]]; then
                update_config "PORTAINER_DOMAIN" "$2"
                # If setting portainer domain, implicitly enable portainer
                update_config "USE_PORTAINER" "true"
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
        --enable-dns-challenge)
            update_config "USE_DNS_CHALLENGE" "true"
            HANDLED_COMMAND=true
            shift
            ;;
        --dns-provider)
            if [[ -n "${2:-}" ]]; then
                if [[ "$2" == "cloudflare" ]]; then
                    update_config "DNS_PROVIDER" "$2"
                    HANDLED_COMMAND=true
                    shift 2
                else
                    log "ERROR" "Unsupported DNS provider: $2"
                    log "INFO" "Currently supported providers: cloudflare"
                    exit 1
                fi
            else
                log "ERROR" "Missing provider value for --dns-provider"
                exit 1
            fi
            ;;
        --cf-email)
            if [[ -n "${2:-}" ]]; then
                if validate_email "$2"; then
                    update_config "CF_API_EMAIL" "$2"
                    HANDLED_COMMAND=true
                    shift 2
                else
                    log "ERROR" "Invalid email format"
                    exit 1
                fi
            else
                log "ERROR" "Missing email value for --cf-email"
                exit 1
            fi
            ;;
        --cf-api-token)
            if [[ -n "${2:-}" ]]; then
                update_config "CF_DNS_API_TOKEN" "$2"
                HANDLED_COMMAND=true
                shift 2
            else
                log "ERROR" "Missing token value for --cf-api-token"
                exit 1
            fi
            ;;
        --enable-traefik-dashboard)
            update_config "ENABLE_TRAEFIK_DASHBOARD" "true"
            HANDLED_COMMAND=true
            shift
            ;;
        --disable-traefik-dashboard)
            update_config "ENABLE_TRAEFIK_DASHBOARD" "false"
            HANDLED_COMMAND=true
            shift
            ;;
        --traefik-dashboard-port)
            if [[ -n "${2:-}" ]]; then
                update_config "TRAEFIK_DASHBOARD_PORT" "$2"
                HANDLED_COMMAND=true
                shift 2
            else
                log "ERROR" "Missing port value for --traefik-dashboard-port"
                exit 1
            fi
            ;;
        --show-dns-config)
            show_dns_config
            HANDLED_COMMAND=true
            shift
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