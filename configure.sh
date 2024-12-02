#!/bin/bash

# Function to check if a command exists - this lets us determine if Docker is already installed
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install Docker using the official installation script
install_docker() {
    echo "Docker is not installed. Installing Docker..."
    
    # Download and run the official Docker installation script
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    
    # Add current user to docker group to avoid needing sudo for docker commands
    sudo usermod -aG docker $USER
    
    echo "Docker installation completed. You may need to log out and back in for group changes to take effect."
    
    # Prompt for shell restart to apply group changes
    read -p "Do you want to restart the shell now to apply docker group changes? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]
    then
        exec su -l $USER
    fi
}

# Function to validate email format using regex
validate_email() {
    local email=$1
    if [[ $email =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
        return 0
    else
        return 1
    fi
}

# Create .env file if it doesn't exist
if [ ! -f .env ]; then
    echo "Creating .env file..."
    touch .env
fi

# Load existing environment variables
if [ -f .env ]; then
    echo "Loading environment variables from .env file..."
    export $(cat .env | xargs)
fi

# Check for Docker installation
if ! command_exists docker; then
    read -p "Docker is not installed. Would you like to install it now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]
    then
        install_docker
    else
        echo "Docker is required to continue. Exiting..."
        exit 1
    fi
fi

# Collect user input for configuration
echo "Please provide the following information:"

# Domain configuration
read -p "Enter your domain name for your portainer instance (e.g., portainer.example.com): " portainer_domain_name
echo "PORTAINER_DOMAIN=$portainer_domain_name" >> .env

# Email configuration with validation
while true; do
    read -p "Enter your email address for SSL certificates: " email_address
    if validate_email "$email_address"; then
        break
    else
        echo "Invalid email format. Please try again."
    fi
done

# Update Traefik configuration with the provided email
if [ -f traefik/traefik.yml ]; then
    sed -i "s/your-email@domain.com/$email_address/" traefik/traefik.yml
else
    echo "Warning: traefik.yml not found. Please make sure to update the email manually."
fi

# Start the containers
echo "Starting Docker containers..."
docker compose up -d

# Check if containers started successfully
if [ $? -eq 0 ]; then
    echo "
Setup completed successfully!

You can access your services at:
- Portainer: https://$portainer_domain_name

Please allow a few minutes for SSL certificates to be generated.
"
else
    echo "An error occurred while starting the containers. Please check the logs."
fi