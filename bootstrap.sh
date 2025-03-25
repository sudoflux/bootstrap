#!/bin/bash

set -e

echo "===== System Bootstrap Script ====="
echo "This script will:"
echo "- Install system updates"
echo "- Install essential tools"
echo "- Clone dotfiles repository"
echo "- Set up SSH keys for GitHub"
echo ""

# Detect OS
if [ -f /etc/os-release ]; then
    # Linux
    . /etc/os-release
    OS_TYPE="linux"
    DISTRO="$ID"
    echo "Detected Linux distribution: $DISTRO"
elif [ "$(uname)" == "Darwin" ]; then
    # macOS
    OS_TYPE="macos"
    echo "Detected macOS"
elif [ "$(expr substr $(uname -s) 1 10)" == "MINGW32_NT" ] || [ "$(expr substr $(uname -s) 1 10)" == "MINGW64_NT" ]; then
    # Windows/Git Bash
    OS_TYPE="windows"
    echo "Detected Windows"
else
    echo "Unsupported OS"
    exit 1
fi

# Install system updates and essential tools based on OS
install_packages() {
    echo "===== Installing System Updates and Essential Tools ====="
    
    if [ "$OS_TYPE" == "linux" ]; then
        if [ "$DISTRO" == "ubuntu" ] || [ "$DISTRO" == "debian" ]; then
            echo "Updating apt repositories..."
            sudo apt update
            
            echo "Installing updates..."
            sudo apt upgrade -y
            
            echo "Installing essential tools..."
            sudo apt install -y curl git build-essential python3 python3-pip
        elif [ "$DISTRO" == "fedora" ] || [ "$DISTRO" == "rhel" ] || [ "$DISTRO" == "centos" ]; then
            echo "Updating dnf repositories..."
            sudo dnf check-update
            
            echo "Installing updates..."
            sudo dnf upgrade -y
            
            echo "Installing essential tools..."
            sudo dnf install -y curl git gcc gcc-c++ make python3 python3-pip
        elif [ "$DISTRO" == "arch" ]; then
            echo "Updating pacman repositories..."
            sudo pacman -Sy
            
            echo "Installing updates..."
            sudo pacman -Syu --noconfirm
            
            echo "Installing essential tools..."
            sudo pacman -S --noconfirm curl git base-devel python python-pip
        else
            echo "Unsupported Linux distribution: $DISTRO"
            echo "Please install the following tools manually: curl, git, build-essential, python3, python3-pip"
        fi
    elif [ "$OS_TYPE" == "macos" ]; then
        # Check if Homebrew is installed
        if ! command -v brew &> /dev/null; then
            echo "Installing Homebrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        fi
        
        echo "Updating Homebrew..."
        brew update
        
        echo "Installing essential tools..."
        brew install curl git python
    elif [ "$OS_TYPE" == "windows" ]; then
        echo "On Windows, please ensure you have installed:"
        echo "- Git for Windows (https://gitforwindows.org/)"
        echo "- Python (https://www.python.org/downloads/windows/)"
        echo "This script has limited functionality on Windows."
    fi
    
    echo "Essential tools installation completed."
}

# Clone dotfiles repository
clone_dotfiles() {
    echo "===== Cloning Dotfiles Repository ====="
    
    if [ -d "$HOME/dotfiles" ]; then
        echo "Dotfiles directory already exists at $HOME/dotfiles"
        echo "Updating existing repository..."
        cd "$HOME/dotfiles"
        git pull
    else
        echo "Cloning dotfiles repository..."
        git clone https://github.com/sudoflux/dotfiles.git "$HOME/dotfiles"
    fi
    
    # Run the dotfiles installer
    echo "Running dotfiles installer..."
    cd "$HOME/dotfiles"
    chmod +x ./install_dotfiles.sh
    ./install_dotfiles.sh
    
    echo "Dotfiles installation completed."
}

# Set up SSH keys
setup_ssh_keys() {
    echo "===== Setting up SSH Keys ====="
    
    # Ensure .ssh directory exists and is secure
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"

    # Generate GitHub SSH key if it doesn't exist
    if [ ! -f "$HOME/.ssh/github_ed25519" ]; then
        echo "Generating GitHub SSH key..."
        ssh-keygen -t ed25519 -C "jfletcherj86@gmail.com" -f "$HOME/.ssh/github_ed25519" -N ""
        echo "GitHub SSH key generated."
        
        echo "===== GitHub SSH Key ====="
        cat "$HOME/.ssh/github_ed25519.pub"
        echo "=========================="
        echo "Please add this key to your GitHub account at: https://github.com/settings/keys"
    else
        echo "GitHub SSH key already exists."
    fi

    # Generate general SSH key if it doesn't exist
    if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
        echo "Generating general SSH key..."
        ssh-keygen -t ed25519 -C "$USER@$(hostname)" -f "$HOME/.ssh/id_ed25519" -N ""
        echo "General SSH key generated."
    else
        echo "General SSH key already exists."
    fi

    # Configure SSH
    SSH_CONFIG="$HOME/.ssh/config"
    
    # Create or update SSH config
    echo "Configuring SSH..."
    
    if [ ! -f "$SSH_CONFIG" ]; then
        touch "$SSH_CONFIG"
    fi
    
    # Check if GitHub host entry exists, add if not
    if ! grep -q "Host github.com" "$SSH_CONFIG"; then
        cat <<EOF >> "$SSH_CONFIG"
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/github_ed25519
    AddKeysToAgent yes

EOF
    fi
    
    # Check if general host entry exists, add if not
    if ! grep -q "Host \*$" "$SSH_CONFIG"; then
        cat <<EOF >> "$SSH_CONFIG"
Host *
    AddKeysToAgent yes
    IdentityFile ~/.ssh/id_ed25519
    StrictHostKeyChecking no
    UserKnownHostsFile=/dev/null
EOF
    fi
    
    chmod 600 "$SSH_CONFIG"
    
    echo "SSH configuration completed."
}

# Main execution
install_packages
clone_dotfiles
setup_ssh_keys

echo "===== Bootstrap Complete ====="
echo "Your system has been set up with:"
echo "- Essential system tools"
echo "- Dotfiles from https://github.com/sudoflux/dotfiles"
echo "- SSH keys for GitHub and general use"
echo ""
echo "Remember to add your GitHub SSH key to your GitHub account!"