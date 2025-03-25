# Bootstrap Script

A comprehensive script to bootstrap new Linux, macOS, and WSL environments with my preferred configuration and tools.

## Features

- **System Updates**: Installs and updates essential system packages
- **SSH Keys**: Generates new SSH keys for GitHub and general use
- **Dotfiles**: Clones and sets up my personal dotfiles repository
- **SSH Server**: Configures the SSH server for remote access
- **Host Management**: Easy SSH access between machines with the hosts_manager.sh script

## Usage

### One-line Setup

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/sudoflux/bootstrap/main/bootstrap.sh)"
```

### Options

- `-v, --verbose`: Enable verbose output
- `-f, --force`: Force update of packages and configurations
- `-h, --help`: Show help message

## Host Manager

The `hosts_manager.sh` script allows you to manage SSH hosts across your machines.

### Features

- **Host Registration**: Automatically registers the current machine in your dotfiles
- **Centralized Config**: Generates a combined hosts file for all registered machines
- **SSH Configuration**: Updates your SSH config for seamless connectivity
- **Two-Phase Sync**: Automatic conflict prevention with pull-before-push strategy
- **Auto-sync**: Optional cron job setup for daily updates

### Usage

After running the bootstrap script, set up host management with:

```bash
curl -fsSL https://raw.githubusercontent.com/sudoflux/bootstrap/main/hosts_manager.sh | bash
```

Or if you've already run bootstrap:

```bash
~/dotfiles/hosts_manager.sh
```

### Options

- `-u, --update-only`: Only update hosts from repository (don't register this host)
- `-a, --auto-sync`: Set up a daily cron job to keep hosts in sync
- `-f, --force-ssh-config`: Force updating the SSH config
- `--setup-cron`: Set up cron job only (no other actions)
- `--remove-cron`: Remove the auto-sync cron job
- `--skip-pull-phase`: Skip the initial pull-only phase (not recommended)

### Best Practices for Multiple Machines

The script now includes automatic two-phase synchronization to prevent conflicts when managing multiple machines:

1. It will automatically pull the latest changes first
2. Then register the current host and push changes

This happens automatically with a single command:

```bash
~/dotfiles/hosts_manager.sh
```

### Important Note on SSH Keys and Passwordless Authentication

The hosts_manager.sh script manages host configurations (IP addresses, usernames, etc.) but **does not** automatically transfer SSH keys between machines for security reasons. To enable passwordless SSH between your machines, you need to manually copy your public keys to each remote server's authorized_keys file:

```bash
# The easiest way (if ssh-copy-id is available)
ssh-copy-id hostname

# Alternative method
cat ~/.ssh/id_ed25519.pub | ssh hostname "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
```

You'll need to do this once from each client machine to each server you want to connect to. After this step, you can SSH between machines without entering passwords.

### Troubleshooting

#### Resolving Merge Conflicts

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
   ~/dotfiles/hosts_manager.sh
   ```

#### SSH Config Issues

If your SSH config doesn't include the hosts file:

```bash
~/dotfiles/hosts_manager.sh -f
```

This forces an update of your SSH config with the correct Include line.