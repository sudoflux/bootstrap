# 🚀 Bootstrap

A powerful bootstrap system to set up new machines with your preferred configuration and keep them seamlessly connected.

## ✨ Features

- 🔍 Detects operating system and installs essential packages
- 🔑 Sets up SSH keys (both for GitHub and general use)
- 📂 Clones and installs dotfiles
- 🔌 Configures SSH server
- 🌐 Provides UDM configuration information
- 🔄 Keeps SSH hosts in sync across all your machines

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

### 🕒 Automatic Host Synchronization

Keep your SSH hosts automatically in sync with a daily cron job:

```bash
# Enable automatic synchronization
bash -c "$(curl -fsSL https://raw.githubusercontent.com/sudoflux/bootstrap/main/hosts_manager.sh)" -- --auto-sync

# Or if already installed:
~/dotfiles/hosts_manager.sh --auto-sync
```

Your hosts will automatically stay in sync daily, so when you add a new machine, all existing machines will be able to connect to it within 24 hours.

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
  --verbose       Enable verbose output
  --help          Show help message
```

## 🤔 Why Use This?

- **🚀 Fast setup**: Get a new machine configured quickly
- **🔄 Consistency**: Same configuration across all your machines
- **✨ Convenience**: Simplified SSH between all your systems
- **🔌 Integration**: Built-in support for UDM/UDM Pro/UDM SE configurations
- **🛡️ Security**: No SSH keys stored in repositories, only connection information
- **📊 Scalability**: Works great with 2 machines or 20+ machines
- **🔁 Idempotent**: Safe to run multiple times

## 📝 License

MIT