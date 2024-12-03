# Docker Setup 4 simple and streamlined docker deployments

Automated infrastructure setup tool for Docker with Traefik, Portainer, and Watchtower.

## Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/jackkweyunga/docker-setup/main/install.sh | bash
```

## Manual Installation

1. Download the latest release from our [releases page](https://github.com/jackkweyunga/docker-setup/releases)
2. Extract the package:
   ```bash
   tar -xzf docker-setup-1.0.0.tar.gz
   ```
3. Install:
   ```bash
   sudo make install
   ```

## Usage

```bash
# Basic setup
docker-setup

# With custom domain
docker-setup --domain example.com

# With custom email
docker-setup --email admin@example.com
```

## Configuration

Configuration files are stored in:
- `/etc/docker-setup/config/`
- `~/.docker-setup/`

## Updating

To update to the latest version:
```bash
docker-setup --update
```

## Contributing

Contributions are welcome! Please read our [contributing guidelines](CONTRIBUTING.md) first.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
