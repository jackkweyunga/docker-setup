# Docker Setup 4 simple and streamlined docker deployments

Automated infrastructure setup tool for Docker with Traefik, Portainer, and Watchtower.

## Features
- [x] Install Docker if not there
- [x] Setup and install Traefik, Portainer and Watchtower
- [x] Update portainer domain command ( --portainer-domain p.example.com )
- [x] Update traefik email command ( --email xxx@xx.xx )
- [x] Update to new version command ( --update )

## Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/jackkweyunga/docker-setup/main/install.sh | bash
```

## Usage

```bash
# Basic setup
docker-setup

# Help
docker-setup --help

# With custom domain
docker-setup --portainer-domain example.com

# With custom email
docker-setup --email admin@example.com
```

## Configuration

Configuration files are stored in:
- `/etc/docker-setup/`

## Updating

To update to the latest version:
```bash
docker-setup --update
```

## Contributing

Contributions are welcome! Please read our [contributing guidelines](CONTRIBUTING.md) first.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
