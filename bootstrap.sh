#!/bin/bash

set -e

# Set global variables
VERBOSE=false
FORCE_UPDATE=false

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_banner() {
    echo -e "${BLUE}===== System Bootstrap Script =====${NC}"
    echo "This script will:"
    echo "- Install system updates (if needed)"
    echo "- Install essential tools (if missing)"
    echo "- Set up SSH keys (if missing)"
    echo "- Clone or update dotfiles repository"
    echo "- Configure SSH server for incoming connections"
    echo ""
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

log_debug() {
    if [ "$VERBOSE" = true ]; then
        echo -e "[DEBUG] $1"
    fi
}

is_package_installed() {
    local package_name=$1
    
    if [ "$OS_TYPE" == "linux" ]; then
        if [ "$DISTRO" == "ubuntu" ] || [ "$DISTRO" == "debian" ]; then
            dpkg -s "$package_name" >/dev/null 2>&1
            return $?
        elif [ "$DISTRO" == "fedora" ] || [ "$DISTRO" == "rhel" ] || [ "$DISTRO" == "centos" ]; then
            rpm -q "$package_name" >/dev/null 2>&1
            return $?
        elif [ "$DISTRO" == "arch" ]; then
            pacman -Qi "$package_name" >/dev/null 2>&1
            return $?
        else
            # Default fallback, may not be accurate
            command -v "$package_name" >/dev/null 2>&1
            return $?
        fi
    elif [ "$OS_TYPE" == "macos" ]; then
        brew list --formula | grep -q "^$package_name\$" >/dev/null 2>&1
        return $?
    elif [ "$OS_TYPE" == "windows" ]; then
        # Just check if the command exists in Windows
        command -v "$package_name" >/dev/null 2>&1
        return $?
    else
        return 1
    fi
}

parse_args() {
    while [ "$#" -gt 0 ]; do
        case "$1" in
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -f|--force)
                FORCE_UPDATE=true
                shift
                ;;
            -h|--help)
                echo "Usage: $0 [options]"
                echo ""
                echo "Options:"
                echo "  -v, --verbose     Enable verbose output"
                echo "  -f, --force       Force update of packages and configurations"
                echo "  -h, --help        Show this help message"
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                echo "Use -h or --help for usage information"
                exit 1
                ;;
        esac
    done
}

# Detect OS
detect_os() {
    log_step "Detecting operating system"
    
    if [ -f /etc/os-release ]; then
        # Linux
        . /etc/os-release
        OS_TYPE="linux"
        DISTRO="$ID"
        log_info "Detected Linux distribution: $DISTRO"
    elif [ "$(uname)" == "Darwin" ]; then
        # macOS
        OS_TYPE="macos"
        log_info "Detected macOS"
    elif [ "$(expr substr $(uname -s) 1 10)" == "MINGW32_NT" ] || [ "$(expr substr $(uname -s) 1 10)" == "MINGW64_NT" ]; then
        # Windows/Git Bash
        OS_TYPE="windows"
        log_info "Detected Windows"
    else
        log_error "Unsupported OS"
        exit 1
    fi
    
    # Get hostname and sanitize it for use in SSH config
    HOSTNAME=$(hostname)
    SANITIZED_HOSTNAME=$(echo "$HOSTNAME" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]-')
    
    # If sanitized hostname is empty for some reason, use a default
    if [ -z "$SANITIZED_HOSTNAME" ]; then
        SANITIZED_HOSTNAME="localhost"
        log_warn "Could not determine valid hostname, using 'localhost'"
    fi
}

# Install system updates and essential tools based on OS
install_packages() {
    log_step "Checking for system updates and essential tools"
    
    # Track if we've modified the system
    local system_updated=false
    local packages_installed=false
    
    if [ "$OS_TYPE" == "linux" ]; then
        if [ "$DISTRO" == "ubuntu" ] || [ "$DISTRO" == "debian" ]; then
            # Define essential packages
            local essential_packages=("curl" "git" "build-essential" "python3" "python3-pip" "openssh-server")
            local missing_packages=()
            
            # Check for missing packages
            for pkg in "${essential_packages[@]}"; do
                if ! is_package_installed "$pkg"; then
                    missing_packages+=("$pkg")
                fi
            done
            
            # Update system if forced or if packages need to be installed
            if [ "$FORCE_UPDATE" = true ] || [ ${#missing_packages[@]} -gt 0 ]; then
                log_info "Updating apt repositories..."
                sudo apt update
                system_updated=true
                
                if [ "$FORCE_UPDATE" = true ]; then
                    log_info "Upgrading system packages (--force enabled)..."
                    sudo apt upgrade -y
                fi
                
                if [ ${#missing_packages[@]} -gt 0 ]; then
                    log_info "Installing missing packages: ${missing_packages[*]}"
                    sudo apt install -y "${missing_packages[@]}"
                    packages_installed=true
                else
                    log_info "All essential packages are already installed"
                fi
            else
                log_info "All essential packages are already installed"
            fi
        elif [ "$DISTRO" == "fedora" ] || [ "$DISTRO" == "rhel" ] || [ "$DISTRO" == "centos" ]; then
            # Define essential packages
            local essential_packages=("curl" "git" "gcc" "gcc-c++" "make" "python3" "python3-pip" "openssh-server")
            local missing_packages=()
            
            # Check for missing packages
            for pkg in "${essential_packages[@]}"; do
                if ! is_package_installed "$pkg"; then
                    missing_packages+=("$pkg")
                fi
            done
            
            # Update system if forced or if packages need to be installed
            if [ "$FORCE_UPDATE" = true ] || [ ${#missing_packages[@]} -gt 0 ]; then
                if [ "$FORCE_UPDATE" = true ]; then
                    log_info "Checking for system updates..."
                    sudo dnf check-update || true  # Ignore exit code 100
                    
                    log_info "Upgrading system packages (--force enabled)..."
                    sudo dnf upgrade -y
                    system_updated=true
                fi
                
                if [ ${#missing_packages[@]} -gt 0 ]; then
                    log_info "Installing missing packages: ${missing_packages[*]}"
                    sudo dnf install -y "${missing_packages[@]}"
                    packages_installed=true
                else
                    log_info "All essential packages are already installed"
                fi
            else
                log_info "All essential packages are already installed"
            fi
        elif [ "$DISTRO" == "arch" ]; then
            # Define essential packages
            local essential_packages=("curl" "git" "base-devel" "python" "python-pip" "openssh")
            local missing_packages=()
            
            # Check for missing packages
            for pkg in "${essential_packages[@]}"; do
                if ! is_package_installed "$pkg"; then
                    missing_packages+=("$pkg")
                fi
            done
            
            # Update system if forced or if packages need to be installed
            if [ "$FORCE_UPDATE" = true ] || [ ${#missing_packages[@]} -gt 0 ]; then
                log_info "Updating pacman repositories..."
                sudo pacman -Sy
                system_updated=true
                
                if [ "$FORCE_UPDATE" = true ]; then
                    log_info "Upgrading system packages (--force enabled)..."
                    sudo pacman -Syu --noconfirm
                fi
                
                if [ ${#missing_packages[@]} -gt 0 ]; then
                    log_info "Installing missing packages: ${missing_packages[*]}"
                    sudo pacman -S --noconfirm "${missing_packages[@]}"
                    packages_installed=true
                else
                    log_info "All essential packages are already installed"
                fi
            else
                log_info "All essential packages are already installed"
            fi
        else
            log_warn "Unsupported Linux distribution: $DISTRO"
            log_info "Please install the following tools manually: curl, git, build-essential, python3, python3-pip, openssh-server"
        fi
    elif [ "$OS_TYPE" == "macos" ]; then
        # Check if Homebrew is installed
        if ! command -v brew &> /dev/null; then
            log_info "Installing Homebrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            system_updated=true
        fi
        
        # Define essential packages
        local essential_packages=("curl" "git" "python")
        local missing_packages=()
        
        # Check for missing packages
        for pkg in "${essential_packages[@]}"; do
            if ! is_package_installed "$pkg"; then
                missing_packages+=("$pkg")
            fi
        done
        
        # Update system if forced or if packages need to be installed
        if [ "$FORCE_UPDATE" = true ] || [ ${#missing_packages[@]} -gt 0 ]; then
            log_info "Updating Homebrew..."
            brew update
            system_updated=true
            
            if [ "$FORCE_UPDATE" = true ]; then
                log_info "Upgrading all packages (--force enabled)..."
                brew upgrade
            fi
            
            if [ ${#missing_packages[@]} -gt 0 ]; then
                log_info "Installing missing packages: ${missing_packages[*]}"
                brew install "${missing_packages[@]}"
                packages_installed=true
            else
                log_info "All essential packages are already installed"
            fi
        else
            log_info "All essential packages are already installed"
        fi
    elif [ "$OS_TYPE" == "windows" ]; then
        log_warn "On Windows, please ensure you have installed:"
        log_warn "- Git for Windows (https://gitforwindows.org/)"
        log_warn "- Python (https://www.python.org/downloads/windows/)"
        log_warn "- OpenSSH Server (via Windows Optional Features)"
        log_warn "This script has limited functionality on Windows."
    fi
    
    # Final status
    if [ "$system_updated" = true ] || [ "$packages_installed" = true ]; then
        log_info "System packages have been updated"
    else
        log_info "No package changes were needed"
    fi
}

# Set up SSH keys and config for outgoing connections
setup_ssh_keys() {
    log_step "Setting up SSH keys and configuration"
    
    # Ensure .ssh directory exists and is secure
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    
    local keys_generated=false

    # Generate GitHub SSH key if it doesn't exist
    if [ ! -f "$HOME/.ssh/github_ed25519" ]; then
        log_info "Generating GitHub SSH key..."
        ssh-keygen -t ed25519 -C "jfletcherj86@gmail.com" -f "$HOME/.ssh/github_ed25519" -N ""
        log_info "GitHub SSH key generated"
        
        echo -e "${YELLOW}===== GitHub SSH Key =====${NC}"
        cat "$HOME/.ssh/github_ed25519.pub"
        echo -e "${YELLOW}==========================${NC}"
        log_warn "Please add this key to your GitHub account at: https://github.com/settings/keys"
        keys_generated=true
    else
        log_info "GitHub SSH key already exists"
    fi

    # Generate general SSH key if it doesn't exist
    if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
        log_info "Generating general SSH key..."
        ssh-keygen -t ed25519 -C "$USER@$HOSTNAME" -f "$HOME/.ssh/id_ed25519" -N ""
        log_info "General SSH key generated"
        keys_generated=true
    else
        log_info "General SSH key already exists"
    fi

    # Configure SSH
    SSH_CONFIG="$HOME/.ssh/config"
    local config_updated=false
    
    # Create or update SSH config
    log_info "Checking SSH configuration..."
    
    if [ ! -f "$SSH_CONFIG" ]; then
        touch "$SSH_CONFIG"
        chmod 600 "$SSH_CONFIG"
    fi
    
    # Check if GitHub host entry exists, add if not
    if ! grep -q "Host github.com" "$SSH_CONFIG"; then
        log_info "Adding GitHub configuration to SSH config..."
        cat <<EOF >> "$SSH_CONFIG"
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/github_ed25519
    AddKeysToAgent yes

EOF
        config_updated=true
    fi
    
    # Check if general host entry exists, add if not
    if ! grep -q "Host \*$" "$SSH_CONFIG"; then
        log_info "Adding default host configuration to SSH config..."
        cat <<EOF >> "$SSH_CONFIG"
Host *
    AddKeysToAgent yes
    IdentityFile ~/.ssh/id_ed25519
    StrictHostKeyChecking no
    UserKnownHostsFile=/dev/null
EOF
        config_updated=true
    fi
    
    chmod 600 "$SSH_CONFIG"
    
    if [ "$keys_generated" = true ] || [ "$config_updated" = true ]; then
        log_info "SSH configuration updated"
    else
        log_info "SSH configuration is already up-to-date"
    fi
}

# Clone or update dotfiles repository and run the installer
setup_dotfiles() {
    log_step "Setting up dotfiles repository"
    
    # Flag to track if dotfiles installer needs to be run
    local run_installer=false
    
    if [ -d "$HOME/dotfiles" ]; then
        log_info "Dotfiles directory already exists at $HOME/dotfiles"
        
        # Check if it's a git repository
        if [ -d "$HOME/dotfiles/.git" ]; then
            log_info "Updating existing repository..."
            cd "$HOME/dotfiles"
            
            # Check for local changes
            if ! git diff --quiet; then
                log_warn "Local changes detected in dotfiles repository"
                if [ "$FORCE_UPDATE" = true ]; then
                    log_warn "Forcing update - stashing local changes"
                    git stash
                    git pull
                    log_info "Dotfiles repository updated (local changes stashed)"
                    run_installer=true
                else
                    log_warn "Skipping update to preserve local changes (use --force to override)"
                    # Still run the installer even if we didn't update
                    run_installer=true
                fi
            else
                # No local changes, safe to pull
                git pull
                log_info "Dotfiles repository updated"
                run_installer=true
            fi
        else
            log_warn "Directory exists but is not a git repository"
            if [ "$FORCE_UPDATE" = true ]; then
                log_warn "Backing up existing directory and cloning fresh"
                mv "$HOME/dotfiles" "$HOME/dotfiles.backup.$(date +%Y%m%d%H%M%S)"
                git clone https://github.com/sudoflux/dotfiles.git "$HOME/dotfiles"
                log_info "Dotfiles repository cloned (old directory backed up)"
                run_installer=true
            else
                log_warn "Skipping dotfiles setup to preserve existing directory (use --force to override)"
            fi
        fi
    else
        log_info "Cloning dotfiles repository..."
        git clone https://github.com/sudoflux/dotfiles.git "$HOME/dotfiles"
        log_info "Dotfiles repository cloned"
        run_installer=true
    fi
    
    # Run the dotfiles installer if needed
    if [ "$run_installer" = true ]; then
        if [ -f "$HOME/dotfiles/install_dotfiles.sh" ]; then
            log_info "Running dotfiles installer..."
            cd "$HOME/dotfiles"
            
            # Make the installer executable if it's not already
            if [ ! -x "$HOME/dotfiles/install_dotfiles.sh" ]; then
                log_info "Making installer executable..."
                chmod +x "$HOME/dotfiles/install_dotfiles.sh"
            fi
            
            # Run the installer
            ./install_dotfiles.sh
            log_info "Dotfiles installation completed"
        else
            log_error "Dotfiles installer not found at $HOME/dotfiles/install_dotfiles.sh"
            log_warn "Skipping dotfiles installation"
        fi
    fi
    
    # Provide info about SSH key setup for future updates
    if [ -f "$HOME/.ssh/github_ed25519" ] && [ -d "$HOME/dotfiles/.git" ]; then
        log_info "To update dotfiles using SSH in the future, you can run:"
        log_info "  cd ~/dotfiles && git remote set-url origin git@github.com:sudoflux/dotfiles.git"
        log_info "But make sure you've added your SSH key to GitHub first!"
    fi
}

# Set up SSH server for incoming connections
setup_ssh_server() {
    log_step "Setting up SSH server for incoming connections"
    
    local server_configured=false
    
    # Set up SSH server based on OS
    if [ "$OS_TYPE" == "linux" ]; then
        # Enable and start SSH server
        if [ "$DISTRO" == "ubuntu" ] || [ "$DISTRO" == "debian" ]; then
            if ! systemctl is-active --quiet ssh; then
                log_info "Enabling and starting SSH server..."
                sudo systemctl enable ssh
                sudo systemctl start ssh
                server_configured=true
            else
                log_info "SSH server is already active"
            fi
            
            # Ensure SSH server is properly configured
            if [ -f "/etc/ssh/sshd_config" ]; then
                # Check if password authentication is properly set
                if grep -q "^PasswordAuthentication no" "/etc/ssh/sshd_config" && [ "$FORCE_UPDATE" = true ]; then
                    log_info "Configuring SSH server to allow password authentication (--force enabled)..."
                    sudo sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
                    sudo systemctl restart ssh
                    server_configured=true
                elif ! grep -q "^PasswordAuthentication" "/etc/ssh/sshd_config"; then
                    log_info "Configuring SSH server to explicitly allow password authentication..."
                    sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
                    sudo systemctl restart ssh
                    server_configured=true
                fi
            fi
        elif [ "$DISTRO" == "fedora" ] || [ "$DISTRO" == "rhel" ] || [ "$DISTRO" == "centos" ]; then
            if ! systemctl is-active --quiet sshd; then
                log_info "Enabling and starting SSH server..."
                sudo systemctl enable sshd
                sudo systemctl start sshd
                server_configured=true
            else
                log_info "SSH server is already active"
            fi
            
            # Ensure SSH server is properly configured
            if [ -f "/etc/ssh/sshd_config" ]; then
                # Check if password authentication is properly set
                if grep -q "^PasswordAuthentication no" "/etc/ssh/sshd_config" && [ "$FORCE_UPDATE" = true ]; then
                    log_info "Configuring SSH server to allow password authentication (--force enabled)..."
                    sudo sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
                    sudo systemctl restart sshd
                    server_configured=true
                elif ! grep -q "^PasswordAuthentication" "/etc/ssh/sshd_config"; then
                    log_info "Configuring SSH server to explicitly allow password authentication..."
                    sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
                    sudo systemctl restart sshd
                    server_configured=true
                fi
            fi
        elif [ "$DISTRO" == "arch" ]; then
            if ! systemctl is-active --quiet sshd; then
                log_info "Enabling and starting SSH server..."
                sudo systemctl enable sshd
                sudo systemctl start sshd
                server_configured=true
            else
                log_info "SSH server is already active"
            fi
            
            # Ensure SSH server is properly configured
            if [ -f "/etc/ssh/sshd_config" ]; then
                # Check if password authentication is properly set
                if grep -q "^PasswordAuthentication no" "/etc/ssh/sshd_config" && [ "$FORCE_UPDATE" = true ]; then
                    log_info "Configuring SSH server to allow password authentication (--force enabled)..."
                    sudo sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
                    sudo systemctl restart sshd
                    server_configured=true
                elif ! grep -q "^PasswordAuthentication" "/etc/ssh/sshd_config"; then
                    log_info "Configuring SSH server to explicitly allow password authentication..."
                    sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
                    sudo systemctl restart sshd
                    server_configured=true
                fi
            fi
        fi
    elif [ "$OS_TYPE" == "macos" ]; then
        # Check if Remote Login is enabled
        if ! systemsetup -getremotelogin | grep -q "On"; then
            log_info "Enabling Remote Login (SSH) on macOS..."
            sudo systemsetup -setremotelogin on
            server_configured=true
        else
            log_info "Remote Login (SSH) is already enabled"
        fi
    elif [ "$OS_TYPE" == "windows" ]; then
        log_warn "On Windows, please enable the OpenSSH Server via:"
        log_warn "Settings > Apps > Optional features > Add a feature > OpenSSH Server"
        log_warn "Then run the following in an admin PowerShell:"
        log_warn "Start-Service sshd"
        log_warn "Set-Service -Name sshd -StartupType 'Automatic'"
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
    local ssh_config_updated=false
    
    # Create host entries for this machine
    if ! grep -q "Host $SANITIZED_HOSTNAME" "$SSH_CONFIG"; then
        log_info "Adding this machine to your SSH config for easy access..."
        
        cat <<EOF >> "$SSH_CONFIG"
# This machine ($HOSTNAME)
Host $SANITIZED_HOSTNAME
    HostName $SANITIZED_HOSTNAME
    User $USER
    AddKeysToAgent yes
    IdentityFile ~/.ssh/id_ed25519

EOF
        ssh_config_updated=true
        
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
    else
        log_info "This machine is already in your SSH config"
        
        # Check if IP entries need updating
        if [ "$FORCE_UPDATE" = true ] && [ ${#IP_ADDRESSES[@]} -gt 0 ]; then
            log_info "Updating IP addresses in SSH config (--force enabled)..."
            
            # Remove existing IP entries for this host
            sed -i.bak "/^# This machine via IP address/d" "$SSH_CONFIG" 2>/dev/null || true
            sed -i.bak "/^Host ${SANITIZED_HOSTNAME}-ip[0-9]*/,/^$/d" "$SSH_CONFIG" 2>/dev/null || true
            
            # Add updated IP entries
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
            ssh_config_updated=true
        fi
    fi

    if [ "$server_configured" = true ] || [ "$ssh_config_updated" = true ]; then
        log_info "SSH server configuration updated"
    else
        log_info "SSH server configuration is already up-to-date"
    fi
    
    log_info "Machine information for UDM configuration:"
    log_info "- Hostname: $HOSTNAME"
    log_info "- Username: $USER"
    
    # Display all IP addresses
    if [ ${#IP_ADDRESSES[@]} -gt 0 ]; then
        log_info "- IP addresses:"
        local i=1
        for IP in "${IP_ADDRESSES[@]}"; do
            log_info "  $i. $IP"
            i=$((i+1))
        done
        
        log_info ""
        log_info "Add this machine to your UDM with:"
        log_info "  Hostname: $SANITIZED_HOSTNAME"
        log_info "  IP: ${IP_ADDRESSES[0]}"
    else
        log_info "- IP address: Could not determine"
    fi
    
    log_info ""
    log_info "After adding to UDM, connect using:"
    log_info "  ssh $SANITIZED_HOSTNAME"
}

# Main function
main() {
    # Parse command line arguments
    parse_args "$@"
    
    # Show banner
    print_banner
    
    # Execute steps in proper order
    detect_os
    install_packages
    setup_ssh_keys
    setup_dotfiles
    setup_ssh_server
    
    log_step "Bootstrap Complete"
    log_info "Your system has been set up with:"
    log_info "- Essential system tools"
    log_info "- SSH keys for GitHub and general use"
    log_info "- Dotfiles from https://github.com/sudoflux/dotfiles"
    log_info "- SSH server for incoming connections"
    log_info ""
    log_info "Remember to add your GitHub SSH key to your GitHub account!"
    log_info ""
    log_info "System information for UDM configuration:"
    log_info "- Hostname: $HOSTNAME"
    log_info "- User: $USER"
    if [ ${#IP_ADDRESSES[@]} -gt 0 ]; then
        log_info "- Primary IP: ${IP_ADDRESSES[0]}"
    else
        log_info "- IP address: Use 'ip addr' or 'ifconfig' to find"
    fi
}

# Run the main function
main "$@"