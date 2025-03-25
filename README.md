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
- Clones your dotfiles repository
- Sets up SSH keys for GitHub and general use
- Configures SSH server for remote access
- Adds machine hostname to SSH config for easy connections
- Provides information for Ubiquiti UDM configuration

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
6. **UDM Integration**:
   - Displays system information for configuring DNS in Ubiquiti UDM
   - Shows IP addresses and hostname for easy reference

## SSH Key Management

The script generates two SSH keys:

1. **GitHub SSH Key**: `~/.ssh/github_ed25519` (for GitHub authentication)
2. **General SSH Key**: `~/.ssh/id_ed25519` (for general SSH connections)

After running the script, remember to add the GitHub SSH key to your GitHub account at: https://github.com/settings/keys

## Ubiquiti UDM Integration

This script is designed to work well with a Ubiquiti UDM for DNS resolution:

1. When you run the bootstrap script, it will display the system's hostname and IP address(es)
2. Add this information to your UDM's DNS records:
   - In the UDM interface, go to Settings > Networks > Your Network > Advanced > DHCP Name Server
   - Add a static DNS record with the hostname and IP address shown by the script
3. Once configured in your UDM, you can connect to the machine using its hostname:
   ```bash
   ssh hostname
   ```

### Example UDM Configuration

After running the script, you'll see output like:

```
Machine information for UDM configuration:
- Hostname: mydevmachine
- Username: developer
- IP addresses:
  1. 192.168.1.50

Add this machine to your UDM with:
  Hostname: mydevmachine
  IP: 192.168.1.50
```

Use this information to add a DNS record in your UDM.

## SSH Config Details

The script automatically adds entries to your SSH config (`~/.ssh/config`) for:

1. **Hostname-based access**: `ssh hostname`
2. **IP-based access**: `ssh hostname-ip1`, `ssh hostname-ip2`, etc. (if multiple network interfaces)

This makes it easy to connect to your machines even before configuring DNS in your UDM.

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