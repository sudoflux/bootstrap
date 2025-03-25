#!/bin/bash

set -e

echo "===== Updating Dotfiles Repository Remote ====="

# Check if dotfiles directory exists
if [ ! -d "$HOME/dotfiles" ]; then
    echo "Error: Dotfiles directory not found at $HOME/dotfiles"
    echo "Please run the bootstrap script first to clone the dotfiles repository."
    exit 1
fi

# Check if GitHub SSH key exists
if [ ! -f "$HOME/.ssh/github_ed25519" ]; then
    echo "Error: GitHub SSH key not found at $HOME/.ssh/github_ed25519"
    echo "Please run the bootstrap script first to generate the SSH keys."
    exit 1
fi

# Check if SSH key is added to GitHub
echo "Before proceeding, please ensure you've added your GitHub SSH key to your GitHub account."
echo "Your GitHub SSH public key is:"
cat "$HOME/.ssh/github_ed25519.pub"
echo ""
read -p "Have you added this key to your GitHub account? (y/n): " key_added

if [ "$key_added" != "y" ] && [ "$key_added" != "Y" ]; then
    echo "Please add your SSH key to GitHub at: https://github.com/settings/keys"
    echo "Then run this script again."
    exit 1
fi

# Update dotfiles remote to use SSH
cd "$HOME/dotfiles"

# Get current remote
current_remote=$(git remote get-url origin)
echo "Current remote: $current_remote"

# Check if already using SSH
if [[ "$current_remote" == git@github.com:* ]]; then
    echo "Remote is already using SSH. No changes needed."
    exit 0
fi

# Update remote to use SSH
echo "Updating remote to use SSH..."
git remote set-url origin git@github.com:sudoflux/dotfiles.git

# Verify the change
new_remote=$(git remote get-url origin)
echo "New remote: $new_remote"

# Test SSH connection
echo "Testing SSH connection to GitHub..."
ssh -T -i "$HOME/.ssh/github_ed25519" git@github.com || true

echo "===== Remote Update Complete ====="
echo "Your dotfiles repository is now configured to use SSH."
echo "You can now push changes to your dotfiles repository using SSH authentication."