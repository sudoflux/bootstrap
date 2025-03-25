# Bootstrap Script

A cross-platform system bootstrap script that automatically sets up a new system with essential tools and configurations.

## Features

- **Idempotent Design**: Safely run multiple times without disrupting existing systems
- **Smart Detection**: Only installs or updates what's needed
- **Preservation**: Preserves local changes and configurations
- **Force Option**: Can force updates when needed with `--force` flag
- **Cross-Platform**: Works on Linux, macOS, and Windows (with limitations)
- **UDM Integration**: Provides information for Ubiquiti UDM configuration

## Supported Operating Systems

- **Linux**:
  - Ubuntu/Debian
  - Fedora/RHEL/CentOS
  - Arch Linux
- **macOS** (via Homebrew)
- **Windows** (limited functionality, provides guidance)

## Quick Install

### Basic Install (Default Options)

```bash
curl -fsSL https://raw.githubusercontent.com/sudoflux/bootstrap/main/bootstrap.sh | bash
```

### With Command Line Arguments

To pass command line arguments like `--force` or `--verbose` when using `curl`, use one of these methods:

**Method 1: Download and run separately**
```bash
# Download the script
curl -fsSL -o bootstrap.sh https://raw.githubusercontent.com/sudoflux/bootstrap/main/bootstrap.sh

# Make executable
chmod +x bootstrap.sh

# Run with arguments
./bootstrap.sh --verbose --force
```

**Method 2: Use bash -s**
```bash
# Download and pipe to bash with arguments
curl -fsSL https://raw.githubusercontent.com/sudoflux/bootstrap/main/bootstrap.sh | bash -s -- --verbose --force
```

Note the `--` after `-s` is needed to separate bash options from the script's options.

## Command Line Options

The script supports several command line options:

- **`-v, --verbose`**: Enable verbose output for detailed logging
- **`-f, --force`**: Force update of packages and configurations, even if they appear up-to-date
- **`-h, --help`**: Display help information

## Failsafe Design

The bootstrap script is designed to be idempotent - you can safely run it multiple times on the same system without causing problems:

1. **Checks Before Changes**: The script checks the current state before making any changes
2. **Minimal Updates**: Only missing or outdated components are updated
3. **Change Detection**: Detects local changes in dotfiles and preserves them by default
4. **Backup Creation**: Creates backups when replacing existing content
5. **Force Option**: The `--force` flag allows you to override safeguards when needed

## What It Does

The script follows these steps, each with built-in safeguards:

1. **System Update**:
   - Checks for missing packages before updating repositories
   - Only upgrades system packages when using `--force`
   - Installs only missing essential tools

2. **Dotfiles**:
   - Detects existing dotfiles repository and updates it
   - Preserves local changes in dotfiles (can override with `--force`)
   - Creates backups when necessary

3. **SSH Setup**:
   - Only generates SSH keys if they don't exist
   - Adds missing SSH config entries without disturbing existing ones
   - Uses color-coded output to highlight important information

4. **SSH Server Configuration**:
   - Only enables SSH server if not already running
   - Makes minimal necessary changes to SSH server configuration
   - Updates IP-based entries in SSH config when using `--force`

## SSH Key Management

The script generates two SSH keys (only if they don't already exist):

1. **GitHub SSH Key**: `~/.ssh/github_ed25519` (for GitHub authentication)
2. **General SSH Key**: `~/.ssh/id_ed25519` (for general SSH connections)

After running the script for the first time, remember to add your GitHub SSH key to your GitHub account at: https://github.com/settings/keys

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

## Examples

### First-time Setup

```bash
# Basic setup with default options
./bootstrap.sh
```

### Checking and Updating an Existing System

```bash
# Check for and apply only necessary updates
./bootstrap.sh

# Force update all components
./bootstrap.sh --force

# Get detailed output during the update
./bootstrap.sh --verbose
```

### Using with CI/CD

```bash
# Non-interactive setup for CI environments
./bootstrap.sh --force
```

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