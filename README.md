# Bootstrap

A simple bootstrap script to set up a new machine with my preferred configuration.

## Features

- Detects operating system and installs essential packages
- Sets up SSH keys (both for GitHub and general use)
- Clones and installs dotfiles
- Configures SSH server
- Provides UDM configuration information

## Usage

### Basic Setup

To bootstrap a new machine, run:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/sudoflux/bootstrap/main/bootstrap.sh)"
```

### SSH Hosts Manager

To enable seamless SSH access between all your machines:

1. Run the bootstrap script on each machine first
2. Then run the hosts manager script:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/sudoflux/bootstrap/main/hosts_manager.sh)"
```

This will:
- Register the current machine in your dotfiles repository
- Add it to a central SSH hosts configuration
- Sync the configuration with all your other machines
- Allow you to SSH between machines using just the hostname (e.g., `ssh ubuntu-dev`)

## Why Use This?

- **Fast setup**: Get a new machine configured quickly
- **Consistency**: Same configuration across all your machines
- **Convenience**: Simplified SSH between all your systems
- **Integration**: Built-in support for UDM/UDM Pro/UDM SE configurations
- **Idempotent**: Safe to run multiple times

## Advanced Options

The bootstrap script accepts several options:

- `--force`: Force recreation of SSH config
- `--no-ssh`: Skip SSH setup
- `--no-dotfiles`: Skip dotfiles setup
- `--no-packages`: Skip package installation
- `--help`: Show help message

## License

MIT