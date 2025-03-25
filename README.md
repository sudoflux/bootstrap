# Bootstrap Script

A cross-platform system bootstrap script that automatically sets up a new system with essential tools and configurations.

## Features

- Detects operating system and installs appropriate packages
- Installs essential development tools:
  - curl
  - git
  - build-essential (or equivalent)
  - python3
  - python3-pip
  - openssh-server (for remote access)
  - avahi-daemon (for .local hostname resolution)
- Clones your dotfiles repository
- Sets up SSH keys for GitHub and general use
- Configures SSH server for remote access
- Adds machine hostname to SSH config for easy connections

## Supported Operating Systems

- **Linux**:
  - Ubuntu/Debian
  - Fedora/RHEL/CentOS
  - Arch Linux
- **macOS** (via Homebrew)
- **Windows** (limited functionality, provides guidance)

## Quick Install

Run this command to download and execute the bootstrap script:

```bash
curl -fsSL https://raw.githubusercontent.com/sudoflux/bootstrap/main/bootstrap.sh | bash
```

Or download and run manually:

```bash
# Download the script
curl -O https://raw.githubusercontent.com/sudoflux/bootstrap/main/bootstrap.sh

# Make it executable
chmod +x bootstrap.sh

# Run it
./bootstrap.sh
```

## What It Does

1. **System Update**: Updates system packages based on your OS
2. **Essential Tools**: Installs development tools (curl, git, build tools, Python)
3. **Dotfiles**: Clones https://github.com/sudoflux/dotfiles to ~/dotfiles and runs the installer
4. **SSH Setup**:
   - Creates GitHub SSH key (if it doesn't exist)
   - Creates general SSH key (if it doesn't exist)
   - Configures SSH settings for security and convenience
5. **SSH Server Configuration**:
   - Installs and enables SSH server
   - Configures system for incoming SSH connections
   - Adds the machine's hostname to SSH config for easy access
   - Enables Avahi daemon for .local hostname resolution (Linux)

## SSH Key Management

The script generates two SSH keys:

1. **GitHub SSH Key**: `~/.ssh/github_ed25519` (for GitHub authentication)
2. **General SSH Key**: `~/.ssh/id_ed25519` (for general SSH connections)

After running the script, remember to add the GitHub SSH key to your GitHub account at: https://github.com/settings/keys

## Remote Access Configuration

The bootstrap script automatically configures the system for SSH access by:

1. Installing and enabling the SSH server
2. Setting up proper SSH server configuration
3. Adding entries to your SSH config file for easy connection:
   - `hostname` - Connect via mDNS/Avahi (.local domain)
   - `hostname-ip` - Connect via IP address
   - `hostname-fqdn` - Connect via fully qualified domain name (if available)

### Connecting to Your Machine

From another system, you can:

1. Copy your SSH key to this machine (first-time setup):
   ```bash
   ssh-copy-id user@hostname.local
   ```

2. Then simply connect using:
   ```bash
   ssh hostname
   ```

The script automatically creates shortcut entries in your SSH config based on the system's hostname.

## Security Considerations

- All SSH keys are generated without passphrases for automation purposes
- SSH server is configured to allow password authentication initially
- The SSH config disables StrictHostKeyChecking and doesn't save known hosts
- Consider adding passphrases to keys manually for additional security
- For production systems, you should disable password authentication and only allow key-based login

## Customization

Feel free to fork this repository and customize the bootstrap script to your needs:

- Add additional software packages to install
- Modify SSH key settings
- Change dotfiles repository location
- Adjust SSH server security settings

## License

MIT