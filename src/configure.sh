#!/bin/bash

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install Docker using the official installation script
install_docker() {
    echo "Docker is not installed. Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    echo "Docker installation completed. You may need to log out and back in for group changes to take effect."
    read -p "Do you want to restart the shell now to apply docker group changes? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        exec su -l $USER
    fi
}

# Function to check configuration files
check_config_files() {
    local missing_files=()
    
    # Check for required directories and files
    [[ ! -d "traefik" ]] && missing_files+=("traefik/")
    [[ ! -f "traefik/traefik.yml" ]] && missing_files+=("traefik/traefik.yml")
    [[ ! -f "docker-compose.yml" ]] && missing_files+=("docker-compose.yml")
    
    if (( ${#missing_files[@]} )); then
        echo "WARNING: The following required files/directories are missing:"
        printf '%s\n' "${missing_files[@]}"
        echo -e "\nPlease ensure these files exist in the following structure:
        ./
        ├── docker-compose.yml
        └── traefik/
            └── traefik.yml\n"
        exit 1
    fi
}

# Function to verify environment variables
verify_env() {
    if [[ -z "$PORTAINER_DOMAIN" || -z "$EMAIL" ]]; then
        return 1
    fi
    return 0
}

# Check for Docker installation
if ! command_exists docker; then
    read -p "Docker is not installed. Would you like to install it now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        install_docker
    else
        echo "Docker is required to continue. Exiting..."
        exit 1
    fi
fi

# Check configuration files
check_config_files

# Load existing environment variables
if [ -f .env ]; then
    echo "Loading environment variables from .env file..."
    export $(cat .env | xargs)
fi

# Only prompt for configuration if environment variables are not set
if ! verify_env; then
    echo "Configuration not found. Please provide the following information:"
    
    # Domain configuration
    read -p "Enter your domain name for your portainer instance (e.g., portainer.example.com): " portainer_domain_name
    echo "PORTAINER_DOMAIN=$portainer_domain_name" >> .env
    
    # Email configuration
    while true; do
        read -p "Enter your email address for SSL certificates: " email_address
        if [[ $email_address =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
            echo "EMAIL=$email_address" >> .env
            break
        else
            echo "Invalid email format. Please try again."
        fi
    done
    
    # Update Traefik configuration
    if [ -f traefik/traefik.yml ]; then
        sed -i "s/your-email@domain.com/$email_address/" traefik/traefik.yml
    fi

    echo "Loading environment variables from .env file..."
    export $(cat .env | xargs)
    
else
    echo "Found existing configuration:"
    echo "- Portainer Domain: $PORTAINER_DOMAIN"
    echo "- Email: $EMAIL"
fi

# Create traefik_network if it doesn't exist
if ! docker network ls | grep -q traefik_network; then
    echo "Creating the traefik_network..."
    docker network create traefik_network
fi

# Start the containers
echo "Starting Docker containers..."
docker compose up -d

# Check if containers started successfully
if [ $? -eq 0 ]; then
    echo "
Setup completed successfully!
You can access your services at:
- Portainer: https://$PORTAINER_DOMAIN

Please allow a few minutes for SSL certificates to be generated.

Configuration files are located at:
- Docker Compose: ./docker-compose.yml
- Traefik Config: ./traefik/traefik.yml
- Environment Variables: ./.env
"
else
    echo "An error occurred while starting the containers. Please check the logs."
fi