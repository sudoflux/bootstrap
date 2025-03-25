# 🚀 Bootstrap Script

<div align="center">

![Version](https://img.shields.io/badge/version-1.1.0-blue.svg)
![Platform](https://img.shields.io/badge/platform-Linux%20|%20macOS%20|%20WSL-lightgrey)
![License](https://img.shields.io/badge/license-MIT-green.svg)

</div>

A comprehensive script to bootstrap new Linux, macOS, and WSL environments with my preferred configuration and tools. Sets up everything from system packages to SSH keys to network configuration in one command.

## ✨ Features

- **🔄 System Updates**: Installs and updates essential system packages
- **🔑 SSH Keys**: Generates new SSH keys for GitHub and general use
- **📁 Dotfiles**: Clones and sets up my personal dotfiles repository
- **🖥️ SSH Server**: Configures the SSH server for remote access
- **🌐 Network**: Configures DNS search domains for seamless local networking
- **🔗 Host Management**: Easy SSH access between machines with the hosts_manager.sh script

## 📋 Usage

### One-line Setup

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/sudoflux/bootstrap/main/bootstrap.sh)"
```

### Options

| Option | Description |
|--------|-------------|
| `-v, --verbose` | Enable verbose output |
| `-f, --force` | Force update of packages and configurations |
| `-d, --domain` | Configure DNS search domain (default: "lab") |
| `-h, --help` | Show help message |

### DNS Search Domain Configuration

The bootstrap script can now configure your network settings to include a search domain, making it easier to access machines on your local network by hostname without specifying the domain:

Set up everything with "lab" as the search domain:
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/sudoflux/bootstrap/main/bootstrap.sh)" -- -d
```

Specify a custom search domain:
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/sudoflux/bootstrap/main/bootstrap.sh)" -- -d mydomain.local
```

With this feature:
- Access local machines using just their hostname (e.g., `ssh server1` instead of `ssh server1.lab`)
- Works with multiple network configuration systems (systemd-resolved, NetworkManager, netplan, direct resolv.conf)
- Safe implementation with backups and non-destructive changes

## 🔄 Host Manager

The `hosts_manager.sh` script allows you to manage SSH hosts across your machines.

### Features

- **🖥️ Host Registration**: Automatically registers the current machine in your dotfiles
- **📄 Centralized Config**: Generates a combined hosts file for all registered machines
- **⚙️ SSH Configuration**: Updates your SSH config for seamless connectivity
- **🔄 Two-Phase Sync**: Automatic conflict prevention with pull-before-push strategy
- **⏱️ Auto-sync**: Optional cron job setup for daily updates
- **🔑 Key Distribution**: Automatically distribute SSH keys to all registered hosts

### Usage

After running the bootstrap script, you can manage hosts in two ways:

1. **Direct curl usage (recommended):**

Register and update hosts:
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/sudoflux/bootstrap/main/hosts_manager.sh)"
```

Distribute SSH keys to all hosts:
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/sudoflux/bootstrap/main/hosts_manager.sh)" -- --distribute-keys
```

Set up automatic sync:
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/sudoflux/bootstrap/main/hosts_manager.sh)" -- --auto-sync
```

Common use case: Distribute keys and set up auto-sync in one command:
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/sudoflux/bootstrap/main/hosts_manager.sh)" -- --distribute-keys --auto-sync
```

2. **If you prefer using the local copy:**
```bash
~/dotfiles/hosts_manager.sh
```

### SSH Key Distribution

The easiest way to set up passwordless SSH between your machines is to use the `--distribute-keys` option. After you've bootstrapped a machine (meaning it has SSH keys and is registered in your dotfiles), you can distribute its SSH key to all other registered hosts with a single command:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/sudoflux/bootstrap/main/hosts_manager.sh)" -- --distribute-keys
```

This will:
1. Use your existing SSH key (created during bootstrap)
2. Copy it to all other registered hosts
3. Set up proper permissions on the remote machines
4. Enable passwordless SSH access from this machine to others

You don't need to run bootstrap again - just this one command will handle the key distribution.

### Quick Setup (Common Workflow)

For new machines, the most common workflow is to distribute SSH keys for passwordless access and enable automatic daily syncing:

All-in-one setup: distribute SSH keys and enable daily automatic syncing:
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/sudoflux/bootstrap/main/hosts_manager.sh)" -- --distribute-keys --auto-sync
```

This single command:
1. Copies your SSH key to all other registered hosts enabling passwordless login
2. Sets up a daily cron job that keeps your hosts file in sync across all machines
3. Shows a summary of successful and failed key distributions

### Options

| Option | Description |
|--------|-------------|
| `-u, --update-only` | Only update hosts from repository (don't register this host) |
| `-a, --auto-sync` | Set up a daily cron job to keep hosts in sync |
| `-f, --force-ssh-config` | Force updating the SSH config |
| `--setup-cron` | Set up cron job only (no other actions) |
| `--remove-cron` | Remove the auto-sync cron job |
| `--skip-pull-phase` | Skip the initial pull-only phase (not recommended) |
| `--distribute-keys` | Copy SSH public key to all registered hosts |

### Best Practices for Multiple Machines

The script includes automatic two-phase synchronization to prevent conflicts when managing multiple machines:

1. It will automatically pull the latest changes first
2. Then register the current host and push changes

This happens automatically with a single command:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/sudoflux/bootstrap/main/hosts_manager.sh)"
```

## 🔒 Security Notes

### SSH Keys and Passwordless Authentication

The hosts_manager.sh script manages host configurations (IP addresses, usernames, etc.) and includes automatic key distribution with the `--distribute-keys` option. When using this feature:

1. **Only the public key is distributed**: Your private key remains secure on your local machine
2. **Multiple authentication methods**: Uses `ssh-copy-id` with fallback to manual methods
3. **Proper permissions**: Ensures correct SSH directory and key file permissions
4. **Progress tracking**: Shows which hosts succeeded/failed during distribution
5. **Manual fallback**: Provides instructions for manual key copying if needed

For manual key distribution (if automatic fails):

Using ssh-copy-id (recommended):
```bash
ssh-copy-id -i ~/.ssh/id_ed25519.pub hostname
```

Alternative manual method:
```bash
cat ~/.ssh/id_ed25519.pub | ssh hostname "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
```

## 🔧 Troubleshooting

### Resolving Merge Conflicts

If you encounter merge conflicts in the hosts file:

1. View the conflict:
   ```bash
   cat ~/dotfiles/ssh_hosts/hosts
   ```

2. Edit the file to resolve conflicts:
   ```bash
   nano ~/dotfiles/ssh_hosts/hosts
   ```
   Remove conflict markers and keep both host entries.

3. Commit the resolved conflict:
   ```bash
   cd ~/dotfiles
   git add ssh_hosts/hosts
   git commit -m "Resolve hosts merge conflict"
   git push
   ```

4. Run hosts_manager again:
   ```bash
   bash -c "$(curl -fsSL https://raw.githubusercontent.com/sudoflux/bootstrap/main/hosts_manager.sh)"
   ```

### SSH Config Issues

If your SSH config doesn't include the hosts file:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/sudoflux/bootstrap/main/hosts_manager.sh)" -- -f
```

This forces an update of your SSH config with the correct Include line.

### Key Distribution Issues

If key distribution fails for some hosts:

1. Check connectivity to the failed hosts:
   ```bash
   ssh hostname
   ```

2. Verify the remote user has proper permissions:
   ```bash
   ssh hostname "ls -la ~/.ssh"
   ```

3. Try manual key distribution:
   ```bash
   ssh-copy-id -i ~/.ssh/id_ed25519.pub hostname
   ```

4. Check SSH agent is running:
   ```bash
   eval $(ssh-agent)
   ssh-add ~/.ssh/id_ed25519
   ```

### Network Configuration Issues

If the search domain configuration doesn't seem to be working:

1. Check your system's network configuration method:
   ```bash
   # For systemd-resolved systems
   resolvectl status

   # For NetworkManager systems
   nmcli connection show

   # For systems using /etc/resolv.conf directly
   cat /etc/resolv.conf
   ```

2. Run bootstrap with verbose flag to see detailed logs:
   ```bash
   bash -c "$(curl -fsSL https://raw.githubusercontent.com/sudoflux/bootstrap/main/bootstrap.sh)" -- -v -d
   ```

3. For persistent configuration on systems where resolv.conf is managed dynamically, you may need to configure the search domain in your network configuration directly.