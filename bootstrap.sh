#!/bin/bash

set -e

echo "===== System Bootstrap Script ====="
echo "This script will:"
echo "- Install system updates"
echo "- Install essential tools"
echo "- Clone dotfiles repository"
echo "- Set up SSH keys for GitHub"
echo "- Configure SSH server for incoming connections"
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
            sudo apt install -y curl git build-essential python3 python3-pip openssh-server
        elif [ "$DISTRO" == "fedora" ] || [ "$DISTRO" == "rhel" ] || [ "$DISTRO" == "centos" ]; then
            echo "Updating dnf repositories..."
            sudo dnf check-update
            
            echo "Installing updates..."
            sudo dnf upgrade -y
            
            echo "Installing essential tools..."
            sudo dnf install -y curl git gcc gcc-c++ make python3 python3-pip openssh-server
        elif [ "$DISTRO" == "arch" ]; then
            echo "Updating pacman repositories..."
            sudo pacman -Sy
            
            echo "Installing updates..."
            sudo pacman -Syu --noconfirm
            
            echo "Installing essential tools..."
            sudo pacman -S --noconfirm curl git base-devel python python-pip openssh
        else
            echo "Unsupported Linux distribution: $DISTRO"
            echo "Please install the following tools manually: curl, git, build-essential, python3, python3-pip, openssh-server"
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
        echo "- OpenSSH Server (via Windows Optional Features)"
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

# Set up SSH keys and config for outgoing connections
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

# Set up SSH server for incoming connections
setup_ssh_server() {
    echo "===== Setting up SSH Server ====="
    
    # Get hostname and sanitize it for use in SSH config
    HOSTNAME=$(hostname)
    SANITIZED_HOSTNAME=$(echo "$HOSTNAME" | tr '[:upper:]' '[:lower:]' | tr -d '[^a-z0-9-]')
    
    # Set up SSH server based on OS
    if [ "$OS_TYPE" == "linux" ]; then
        # Enable and start SSH server
        if [ "$DISTRO" == "ubuntu" ] || [ "$DISTRO" == "debian" ]; then
            echo "Enabling SSH server..."
            sudo systemctl enable ssh
            sudo systemctl start ssh
            
            # Ensure SSH server is running and accepting connections
            echo "Configuring SSH server..."
            if [ -f "/etc/ssh/sshd_config" ]; then
                # Ensure password authentication is enabled for initial setup
                sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
                sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
                
                # Restart SSH server to apply changes
                sudo systemctl restart ssh
            fi
        elif [ "$DISTRO" == "fedora" ] || [ "$DISTRO" == "rhel" ] || [ "$DISTRO" == "centos" ]; then
            echo "Enabling SSH server..."
            sudo systemctl enable sshd
            sudo systemctl start sshd
            
            # Ensure SSH server is running and accepting connections
            echo "Configuring SSH server..."
            if [ -f "/etc/ssh/sshd_config" ]; then
                # Ensure password authentication is enabled for initial setup
                sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
                sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
                
                # Restart SSH server to apply changes
                sudo systemctl restart sshd
            fi
        elif [ "$DISTRO" == "arch" ]; then
            echo "Enabling SSH server..."
            sudo systemctl enable sshd
            sudo systemctl start sshd
            
            # Ensure SSH server is running and accepting connections
            echo "Configuring SSH server..."
            if [ -f "/etc/ssh/sshd_config" ]; then
                # Ensure password authentication is enabled for initial setup
                sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
                sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
                
                # Restart SSH server to apply changes
                sudo systemctl restart sshd
            fi
        fi
    elif [ "$OS_TYPE" == "macos" ]; then
        echo "Enabling Remote Login (SSH) on macOS..."
        sudo systemsetup -setremotelogin on
    elif [ "$OS_TYPE" == "windows" ]; then
        echo "On Windows, please enable the OpenSSH Server via:"
        echo "Settings > Apps > Optional features > Add a feature > OpenSSH Server"
        echo "Then run the following in an admin PowerShell:"
        echo "Start-Service sshd"
        echo "Set-Service -Name sshd -StartupType 'Automatic'"
    fi

    # Get IP addresses for the machine
    # This supports multiple network interfaces and different OS types
    declare -a IP_ADDRESSES
    
    if [ "$OS_TYPE" == "linux" ]; then
        # Get IP addresses from Linux
        if command -v ip &> /dev/null; then
            # Modern Linux with ip command
            readarray -t IP_ADDRESSES < <(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1')
        elif command -v ifconfig &> /dev/null; then
            # Older Linux with ifconfig
            readarray -t IP_ADDRESSES < <(ifconfig | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1')
        fi
    elif [ "$OS_TYPE" == "macos" ]; then
        # Get IP addresses from macOS
        readarray -t IP_ADDRESSES < <(ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}')
    elif [ "$OS_TYPE" == "windows" ]; then
        # Get IP addresses from Windows/Git Bash
        readarray -t IP_ADDRESSES < <(ipconfig | grep -i "IPv4 Address" | grep -oP '(?<=:\s)\d+(\.\d+){3}')
    fi
    
    # Add system host entry to SSH config for easy connection
    SSH_CONFIG="$HOME/.ssh/config"
    
    # Create host entries for this machine
    if ! grep -q "Host $SANITIZED_HOSTNAME" "$SSH_CONFIG"; then
        echo "Adding this machine to your SSH config for easy access..."
        
        cat <<EOF >> "$SSH_CONFIG"
# This machine ($HOSTNAME)
Host $SANITIZED_HOSTNAME
    HostName $SANITIZED_HOSTNAME
    User $USER
    AddKeysToAgent yes
    IdentityFile ~/.ssh/id_ed25519

EOF
        
        # Add each IP address as a separate entry
        if [ ${#IP_ADDRESSES[@]} -gt 0 ]; then
            local i=1
            for IP in "${IP_ADDRESSES[@]}"; do
                cat <<EOF >> "$SSH_CONFIG"
# This machine via IP address $i
Host ${SANITIZED_HOSTNAME}-ip${i}
    HostName $IP
    User $USER
    AddKeysToAgent yes
    IdentityFile ~/.ssh/id_ed25519

EOF
                i=$((i+1))
            done
        fi
    fi

    echo "SSH server setup completed."
    echo ""
    echo "To connect to this machine using your Ubiquiti UDM SE for DNS resolution:"
    echo ""
    
    # Display hostname and IP information
    echo "Machine information for UDM configuration:"
    echo "- Hostname: $HOSTNAME"
    echo "- Username: $USER"
    
    # Display all IP addresses
    if [ ${#IP_ADDRESSES[@]} -gt 0 ]; then
        echo "- IP addresses:"
        local i=1
        for IP in "${IP_ADDRESSES[@]}"; do
            echo "  $i. $IP"
            i=$((i+1))
        done
        
        echo ""
        echo "Add this machine to your UDM with:"
        echo "  Hostname: $SANITIZED_HOSTNAME"
        echo "  IP: ${IP_ADDRESSES[0]}"
    else
        echo "- IP address: Could not determine"
    fi
    
    echo ""
    echo "After adding to UDM, connect using:"
    echo "  ssh $SANITIZED_HOSTNAME"
    echo ""
}

# Main execution
install_packages
clone_dotfiles
setup_ssh_keys
setup_ssh_server

echo "===== Bootstrap Complete ====="
echo "Your system has been set up with:"
echo "- Essential system tools"
echo "- Dotfiles from https://github.com/sudoflux/dotfiles"
echo "- SSH keys for GitHub and general use"
echo "- SSH server for incoming connections"
echo ""
echo "Remember to add your GitHub SSH key to your GitHub account!"
echo ""
echo "System information for UDM configuration:"
echo "- Hostname: $(hostname)"
echo "- User: $USER"
if [ ${#IP_ADDRESSES[@]} -gt 0 ]; then
    echo "- Primary IP: ${IP_ADDRESSES[0]}"
else
    echo "- IP address: Use 'ip addr' or 'ifconfig' to find"
fi