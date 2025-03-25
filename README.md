# 🚀 Bootstrap

A powerful bootstrap system to set up new machines with your preferred configuration and keep them seamlessly connected.

## ✨ Features

- 🔍 Detects operating system and installs essential packages
- 🔑 Sets up SSH keys (both for GitHub and general use)
- 📂 Clones and installs dotfiles
- 🔌 Configures SSH server
- 🌐 Provides UDM configuration information
- 🔄 Keeps SSH hosts in sync across all your machines
- 🛡️ Maintains security by never sharing private keys

## 📋 Usage

### 🚀 Basic Setup

To bootstrap a new machine, run:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/sudoflux/bootstrap/main/bootstrap.sh)"
```

### 🔄 SSH Hosts Manager

To enable seamless SSH access between all your machines:

1. Run the bootstrap script on each machine first
2. Then run the hosts manager script:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/sudoflux/bootstrap/main/hosts_manager.sh)"
```

This will:
- ✅ Register the current machine in your dotfiles repository
- 📝 Add it to a central SSH hosts configuration
- 🔄 Sync the configuration with all your other machines
- 🔑 Allow you to SSH between machines using just the hostname (e.g., `ssh ubuntu-dev`)
- 🛡️ Maintain proper security by never sharing private keys

### 🕒 Automatic Host Synchronization

Keep your SSH hosts automatically in sync with a daily cron job:

```bash
# Enable automatic synchronization
bash -c "$(curl -fsSL https://raw.githubusercontent.com/sudoflux/bootstrap/main/hosts_manager.sh)" -- --auto-sync

# Or if already installed:
~/dotfiles/hosts_manager.sh --auto-sync
```

Your hosts will automatically stay in sync daily, so when you add a new machine, all existing machines will be able to connect to it within 24 hours.

### 🔄 Best Practices for Multiple Machines

When managing multiple machines, follow these steps to prevent conflicts:

```bash
# 1. First, update without registering to get the latest changes
~/dotfiles/hosts_manager.sh --update-only

# 2. Only after that succeeds, register your host
~/dotfiles/hosts_manager.sh
```

This two-step approach ensures you don't create conflicting changes when configuring multiple machines at the same time.

## 🛠 Advanced Options

### Bootstrap Script Options

```bash
bootstrap.sh [options]
  --force         Force recreation of SSH config
  --no-ssh        Skip SSH setup
  --no-dotfiles   Skip dotfiles setup
  --no-packages   Skip package installation
  --help          Show help message
```

### Hosts Manager Options

```bash
hosts_manager.sh [options]
  --update-only   Only update hosts from repository (don't register this host)
  --auto-sync     Set up a daily cron job to keep hosts in sync
  --setup-cron    Set up cron job only (no other actions)
  --remove-cron   Remove the auto-sync cron job
  -f, --force-ssh-config  Force update SSH config even if already included
  --verbose       Enable verbose output
  --help          Show help message
```

## 🤔 Why Use This?

- **🚀 Fast setup**: Get a new machine configured quickly
- **🔄 Consistency**: Same configuration across all your machines
- **✨ Convenience**: Simplified SSH between all your systems
- **🔌 Integration**: Built-in support for UDM/UDM Pro/UDM SE configurations
- **🛡️ Security**: Stores host configurations in the secure `ssh_hosts` directory, completely separate from your private keys
- **📊 Scalability**: Works great with 2 machines or 20+ machines
- **🔁 Idempotent**: Safe to run multiple times
- **🧰 Adaptable**: Works on Linux, macOS, and even in special environments like Proxmox

## 🔒 Security Details

The SSH Hosts Manager is carefully designed with security in mind:

- ✅ Private SSH keys are **never** shared or stored in the repository
- ✅ Only connection information (hostnames, IP addresses, usernames) is synchronized
- ✅ Host configurations are stored in a dedicated `ssh_hosts` directory, not in `.ssh`
- ✅ Automatically manages `.gitignore` to protect sensitive files 
- ✅ Sets proper file permissions (600) on SSH configuration files

## 🔍 Troubleshooting

### Handling Merge Conflicts

If you see a merge conflict when running the script, it means two machines updated the hosts file at the same time. To resolve:

1. Edit the conflicted file (usually `~/dotfiles/ssh_hosts/hosts`)
2. Keep all host entries from both sides of the conflict
3. Remove the conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`)
4. Save and commit:
   ```bash
   git add ssh_hosts/hosts
   git commit -m "Merge hosts from multiple machines"
   git push
   ```

### Fixing SSH Config Issues

If SSH isn't recognizing your host configurations:

```bash
# Force update of your SSH config
~/dotfiles/hosts_manager.sh -f
```

This will ensure the correct Include directive is in your SSH config file.

## 📝 License

MIT