# Docker Setup

![Version](https://img.shields.io/github/v/release/jackkweyunga/docker-setup)
![License](https://img.shields.io/github/license/jackkweyunga/docker-setup)

> 🚀 Simple and streamlined Docker deployments with zero hassle

Docker Setup is a lightweight tool that automates the deployment of Docker infrastructure with a reverse proxy, container management, and automated updates. Perfect for self-hosting applications with minimal configuration.

## 📋 Features

- **Zero-Dependency Installation**: Simple Bash script that works on any Linux distribution
- **Automatic Docker Setup**: Installs Docker if not already present
- **Reverse Proxy with Traefik**: Automatic HTTPS with Let's Encrypt certificates
- **Container Management UI**: Optional Portainer integration for easy container management
- **Automatic Updates**: Optional Watchtower integration for keeping containers up-to-date
- **DNS Challenge Support**: Configure DNS verification for wildcard certificates (Cloudflare supported)
- **Profile-Based Deployment**: Flexible component selection through Docker Compose profiles
- **Command-Line Management**: Easy configuration through command-line options
- **Traefik Dashboard**: Optional access to Traefik's monitoring interface

## 🧰 Prerequisites

- A Linux server (Debian, Ubuntu, CentOS, etc.)
- Root/sudo access
- Internet connectivity
- A domain name (for HTTPS)

## 🔧 Installation

### Quick Install (Latest Version)

```bash
curl -fsSL https://raw.githubusercontent.com/jackkweyunga/docker-setup/main/install.sh | bash
```

### Install Specific Version

```bash
curl -fsSL https://raw.githubusercontent.com/jackkweyunga/docker-setup/main/install.sh | bash -s -- --version 1.1.2
```

### Development Install

If you've cloned the repository and want to install from your local copy:

```bash
cd docker-setup
./install.sh --dev
```

## 🚀 Usage

### Basic Setup

Run the tool with sudo to start the interactive setup:

```bash
sudo docker-setup
```

The interactive setup will ask for:
- Email address (for SSL certificates)
- Whether to enable Portainer
- Portainer domain (if enabled)
- Whether to enable the Traefik dashboard
- Whether to use DNS challenge for certificates

### Command-Line Options

```bash
# Show help
sudo docker-setup --help

# Set Portainer domain
sudo docker-setup --portainer-domain portainer.example.com

# Set email for SSL certificates
sudo docker-setup --email admin@example.com

# Enable Traefik dashboard
sudo docker-setup --enable-traefik-dashboard --traefik-dashboard-port 8080

# Enable DNS challenge with Cloudflare
sudo docker-setup --enable-dns-challenge --dns-provider cloudflare --cf-email user@example.com --cf-api-token your_token

# Update to the latest version
sudo docker-setup --update
```

## ⚙️ Configuration

Configuration files are stored in:
- `/etc/docker-setup/`

### Key Files

- `/etc/docker-setup/docker-compose.yml`: Service definitions
- `/etc/docker-setup/traefik/traefik.yml`: Traefik configuration
- `/etc/docker-setup/.env`: Environment variables

### Docker Compose Profiles

The tool uses Docker Compose profiles for flexible deployment:

- **Default**: Traefik (always deployed)
- **portainer**: Portainer container management UI
- **ui**: Traefik dashboard interface
- **maintenance**: Watchtower for automatic updates
- **all**: All components

The tool automatically selects the appropriate profiles based on your configuration choices.

## 🌐 Using with Your Applications

After setup, add your own services with Traefik integration:

```yaml
# Example docker-compose.yml for your application
services:
  my-app:
    image: my-app-image
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.my-app.rule=Host(`app.example.com`)"
      - "traefik.http.routers.my-app.entrypoints=websecure"
      - "traefik.http.routers.my-app.tls.certresolver=production"
    networks:
      - traefik_network

networks:
  traefik_network:
    external: true
```

## 🔄 Updating

To update to the latest version:

```bash
sudo docker-setup --update
```

## 🚧 Troubleshooting

### Common Issues

1. **"Network traefik_network not found"**  
   Solution: Create the network manually:
   ```bash
   sudo docker network create traefik_network
   ```

2. **SSL certificate issues**  
   Solution: 
   - Ensure your domain points to your server
   - Verify ports 80 and 443 are open
   - Check for valid email address

3. **Services not visible**  
   Solution:
   - Check that services are connected to `traefik_network`
   - Verify Traefik labels are correctly configured
   - Inspect logs: `sudo docker logs traefik`

### Viewing Logs

```bash
# Traefik logs
sudo docker logs traefik

# Portainer logs
sudo docker logs portainer
```

## 📚 Advanced Topics

### DNS Challenge for Wildcard Certificates

To set up DNS challenge with Cloudflare:

```bash
sudo docker-setup --enable-dns-challenge --dns-provider cloudflare --cf-email user@example.com --cf-api-token your_token
```

#### Creating a Cloudflare API Token

1. Log in to Cloudflare
2. Go to My Profile → API Tokens
3. Create a token with Zone:DNS:Edit permissions
4. Use this token with the `--cf-api-token` parameter

### Setting Up Subdomains with Cloudflare

To host services with wildcard subdomains with Cloudflare DNS:

1. **Configure DNS Challenge** as shown above.

2. **Create A/CNAME Records in Cloudflare**:
   - Create an A record pointing your root domain to your server IP
   - Create CNAME records for each subdomain pointing to your root domain
   
   Example Cloudflare DNS settings:
   ```
   Type    Name            Content           Proxy Status
   A       *               your.server.ip    Proxied
   A       example.com     your.server.ip    Proxied
   ```

3. **Use Traefik Labels to specify a HostRegexp and/or Host rule(s)**:

   ```yaml
   # Example docker-compose.yml for wilddcard subdomains
   services:
     web-app:
       image: webapp:latest
       labels:
         - "traefik.enable=true"
         - "traefik.http.routers.webapp.rule=Host(`example.com`) || HostRegexp(`.+\.example\.com`)"
         - "traefik.http.routers.webapp.entrypoints=websecure"
         - "traefik.http.routers.webapp.tls.certresolver=cloudflare"
         - "traefik.http.routers.tidp.tls.domains[0].main=example.com"
         - "traefik.http.routers.tidp.tls.domains[0].sans=*.example.com"
       networks:
         - traefik_network
   
   networks:
     traefik_network:
       external: true
   ```

4. **Apply Configuration**:
   ```bash
   docker compose up -d
   ```

This will automatically generate a wildcard SSL certificates for each subdomain using the Cloudflare DNS challenge.

### Customizing Traefik Configuration

Edit the Traefik configuration:

```bash
sudo nano /etc/docker-setup/traefik/traefik.yml
```

Restart Traefik to apply changes:

```bash
sudo docker restart traefik
```

## 👥 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

Documentation: https://jackkweyunga.hashnode.dev/docker-setup-a-tool-for-simple-self-hosted-infrastructure

Created by [Jack Kweyunga](https://github.com/jackkweyunga)
