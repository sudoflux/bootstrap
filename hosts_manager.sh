#!/bin/bash

# hosts_manager.sh - Manages known hosts in dotfiles repository
# This script helps maintain a collection of all hosts you've bootstrapped
# across your environment, syncing them to your dotfiles repo for seamless SSH.

set -e

# Global variables
VERBOSE=false
AUTO_SYNC=false
UPDATE_ONLY=false
CRON_SETUP=false
CRON_UNINSTALL=false

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Paths
DOTFILES_DIR="$HOME/dotfiles"
HOSTS_DIR="$DOTFILES_DIR/.ssh/hosts.d"
HOSTS_FILE="$DOTFILES_DIR/.ssh/hosts"
SSH_CONFIG="$HOME/.ssh/config"
SCRIPT_PATH="$DOTFILES_DIR/hosts_manager.sh"

# Parse command line arguments
parse_args() {
    while [ "$#" -gt 0 ]; do
        case "$1" in
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -u|--update-only)
                UPDATE_ONLY=true
                shift
                ;;
            -a|--auto-sync)
                AUTO_SYNC=true
                shift
                ;;
            --setup-cron)
                CRON_SETUP=true
                shift
                ;;
            --remove-cron)
                CRON_UNINSTALL=true
                shift
                ;;
            -h|--help)
                echo "Usage: $0 [options]"
                echo ""
                echo "Options:"
                echo "  -v, --verbose       Enable verbose output"
                echo "  -u, --update-only   Only update hosts from repository (don't register this host)"
                echo "  -a, --auto-sync     Set up a daily cron job to keep hosts in sync"
                echo "  --setup-cron        Set up cron job only (no other actions)"
                echo "  --remove-cron       Remove the auto-sync cron job"
                echo "  -h, --help          Show this help message"
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

# Log functions
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }
log_debug() {
    if [ "$VERBOSE" = true ]; then
        echo -e "[DEBUG] $1"
    fi
}

# Check prerequisites
check_prereqs() {
    log_step "Checking prerequisites"
    
    if [ ! -d "$DOTFILES_DIR" ]; then
        log_error "Dotfiles directory not found at $DOTFILES_DIR"
        log_error "Please run the bootstrap script first to set up your dotfiles"
        exit 1
    fi
    
    # Ensure the hosts directory exists
    mkdir -p "$HOSTS_DIR"
    
    # Ensure the hosts file exists
    touch "$HOSTS_FILE"
    
    # Copy this script to dotfiles if it doesn't exist there
    if [ ! -f "$SCRIPT_PATH" ] && [ -f "$0" ] && [ "$0" != "$SCRIPT_PATH" ]; then
        log_info "Copying hosts_manager.sh to dotfiles for future use"
        cp "$0" "$SCRIPT_PATH"
        chmod +x "$SCRIPT_PATH"
    fi
    
    log_info "Prerequisites checked"
}

# Register the current host
register_host() {
    if [ "$UPDATE_ONLY" = true ]; then
        log_info "Update-only mode: Skipping host registration"
        return
    fi
    
    log_step "Registering this host in your dotfiles"
    
    # Get hostname and sanitize it
    HOSTNAME=$(hostname)
    SANITIZED_HOSTNAME=$(echo "$HOSTNAME" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]-')
    
    # If sanitized hostname is empty, use a default
    if [ -z "$SANITIZED_HOSTNAME" ]; then
        SANITIZED_HOSTNAME="localhost"
        log_warn "Could not determine valid hostname, using 'localhost'"
    fi
    
    # Get IP addresses
    declare -a IP_ADDRESSES
    if command -v ip &> /dev/null; then
        # Modern Linux with ip command
        readarray -t IP_ADDRESSES < <(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1')
    elif command -v ifconfig &> /dev/null; then
        # Older Linux with ifconfig
        readarray -t IP_ADDRESSES < <(ifconfig | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1')
    elif command -v ipconfig &> /dev/null; then
        # Windows
        readarray -t IP_ADDRESSES < <(ipconfig | grep -i "IPv4 Address" | grep -oP '(?<=:\s)\d+(\.\d+){3}')
    elif [ "$(uname)" == "Darwin" ]; then
        # macOS
        readarray -t IP_ADDRESSES < <(ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}')
    fi
    
    # Create host file in hosts.d directory
    HOST_FILE="$HOSTS_DIR/$SANITIZED_HOSTNAME.conf"
    
    # Generate host entry
    log_info "Creating host entry for $SANITIZED_HOSTNAME"
    
    cat > "$HOST_FILE" <<EOF
# Host: $HOSTNAME
# Added: $(date)
# User: $USER
Host $SANITIZED_HOSTNAME
    HostName ${IP_ADDRESSES[0]}
    User $USER
    AddKeysToAgent yes
    IdentityFile ~/.ssh/id_ed25519
    StrictHostKeyChecking no

EOF
    
    # Add IP-based aliases if available
    if [ ${#IP_ADDRESSES[@]} -gt 1 ]; then
        log_info "Adding additional IP addresses as aliases"
        local i=1
        for IP in "${IP_ADDRESSES[@]:1}"; do  # Skip the first IP as it's already used above
            cat >> "$HOST_FILE" <<EOF
# IP alias $i for $HOSTNAME
Host ${SANITIZED_HOSTNAME}-ip${i}
    HostName $IP
    User $USER
    AddKeysToAgent yes
    IdentityFile ~/.ssh/id_ed25519
    StrictHostKeyChecking no

EOF
            i=$((i+1))
        done
    fi
    
    log_info "Host registered: $SANITIZED_HOSTNAME (${IP_ADDRESSES[0]})"
}

# Generate the combined hosts file
generate_hosts_file() {
    log_step "Generating combined hosts file"
    
    # Clear the hosts file
    cat > "$HOSTS_FILE" <<EOF
# SSH Hosts File - Auto-generated
# This file contains all hosts registered via bootstrap
# Last updated: $(date)
#
# DO NOT EDIT THIS FILE DIRECTLY
# Add or modify files in .ssh/hosts.d/ instead

EOF
    
    # Append all host files
    local count=0
    for host_file in "$HOSTS_DIR"/*.conf; do
        if [ -f "$host_file" ]; then
            cat "$host_file" >> "$HOSTS_FILE"
            count=$((count+1))
        fi
    done
    
    log_info "Combined $count hosts into $HOSTS_FILE"
}

# Commit changes to dotfiles
commit_changes() {
    if [ "$UPDATE_ONLY" = true ] && [ "$VERBOSE" != true ]; then
        # Skip verbose output in update-only mode unless verbose is enabled
        return
    fi
    
    log_step "Committing changes to dotfiles repository"
    
    cd "$DOTFILES_DIR"
    
    if git status --porcelain | grep -q ""; then
        log_info "Changes detected, committing to dotfiles repository"
        
        # Stage the changes
        git add "$HOSTS_DIR" "$HOSTS_FILE"
        
        # Commit with a descriptive message
        git commit -m "Update SSH hosts: add/update $SANITIZED_HOSTNAME"
        
        # Check if we can push
        if [ -f "$HOME/.ssh/github_ed25519" ]; then
            log_info "Attempting to push changes to GitHub"
            if git remote -v | grep -q "git@github.com"; then
                # SSH authentication already set up
                git push && log_info "Changes pushed to GitHub" || log_warn "Could not push to GitHub. Add your SSH key to GitHub first."
            else
                log_info "For future updates, consider switching to SSH authentication:"
                log_info "  cd $DOTFILES_DIR && git remote set-url origin git@github.com:sudoflux/dotfiles.git"
                log_info "  git push"
            fi
        else
            log_warn "GitHub SSH key not found. Changes committed locally only."
            log_info "To push later, run: cd $DOTFILES_DIR && git push"
        fi
    else
        log_info "No changes to commit"
    fi
}

# Install the generated hosts file into SSH config
install_hosts() {
    log_step "Installing hosts file to SSH config"
    
    # Check if hosts inclusion already exists in SSH config
    if ! grep -q "Include $HOSTS_FILE" "$SSH_CONFIG" 2>/dev/null; then
        log_info "Adding hosts file inclusion to SSH config"
        
        # Back up SSH config first
        cp "$SSH_CONFIG" "$SSH_CONFIG.bak.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true
        
        # Add the include line at the top of the SSH config
        if [ -s "$SSH_CONFIG" ]; then
            # File exists and has content
            sed -i.bak "1i\\
# Include generated hosts file from dotfiles\\
Include $HOSTS_FILE\\
" "$SSH_CONFIG" 2>/dev/null || \
            echo -e "# Include generated hosts file from dotfiles\nInclude $HOSTS_FILE\n\n$(cat "$SSH_CONFIG")" > "$SSH_CONFIG"
        else
            # File doesn't exist or is empty
            echo -e "# Include generated hosts file from dotfiles\nInclude $HOSTS_FILE\n" > "$SSH_CONFIG"
        fi
        
        log_info "Hosts file included in SSH config"
    else
        log_info "Hosts file already included in SSH config"
    fi
    
    # Make sure permissions are correct
    chmod 600 "$SSH_CONFIG" "$HOSTS_FILE" 2>/dev/null || true
}

# Set up cron job for automatic sync
setup_cron() {
    log_step "Setting up automatic sync via cron"
    
    if ! command -v crontab >/dev/null 2>&1; then
        log_warn "Cron is not available on this system. Skipping auto-sync setup."
        return 1
    fi
    
    # Make sure the script exists in dotfiles
    if [ ! -f "$SCRIPT_PATH" ]; then
        if [ -f "$0" ] && [ "$0" != "$SCRIPT_PATH" ]; then
            log_info "Copying hosts_manager.sh to dotfiles for cron use"
            cp "$0" "$SCRIPT_PATH"
            chmod +x "$SCRIPT_PATH"
        else
            log_error "Cannot find hosts_manager.sh to set up cron job"
            return 1
        fi
    fi
    
    # Remove any existing cron entry first
    crontab -l 2>/dev/null | grep -v "hosts_manager.sh" | crontab -
    
    # Add new cron job to run daily at 3:00 AM
    (crontab -l 2>/dev/null; echo "0 3 * * * $SCRIPT_PATH --update-only >/dev/null 2>&1") | crontab -
    
    log_info "Auto-sync cron job set up to run daily at 3:00 AM"
    return 0
}

# Remove cron job
remove_cron() {
    log_step "Removing automatic sync cron job"
    
    if ! command -v crontab >/dev/null 2>&1; then
        log_warn "Cron is not available on this system."
        return 1
    fi
    
    # Remove the cron entry
    crontab -l 2>/dev/null | grep -v "hosts_manager.sh" | crontab -
    
    log_info "Auto-sync cron job removed"
    return 0
}

# Sync dotfiles
sync_dotfiles() {
    log_step "Syncing dotfiles repository"
    
    cd "$DOTFILES_DIR"
    
    # Pull the latest changes
    log_info "Pulling latest changes from repository"
    
    if git pull; then
        log_info "Dotfiles repository updated"
    else
        log_warn "Failed to pull latest changes. Local changes may be present."
        log_info "Consider manually running: cd $DOTFILES_DIR && git stash && git pull"
    fi
}

# Main function
main() {
    # Parse command line arguments
    parse_args "$@"
    
    # Handle cron-only operations
    if [ "$CRON_SETUP" = true ]; then
        check_prereqs
        setup_cron
        exit 0
    fi
    
    if [ "$CRON_UNINSTALL" = true ]; then
        remove_cron
        exit 0
    fi
    
    # Regular operation
    log_step "SSH Hosts Manager"
    echo "This script manages shared SSH hosts across your machines"
    echo "It will add this host to your dotfiles repository and"
    echo "update your SSH config to include all known hosts"
    echo ""
    
    check_prereqs
    sync_dotfiles
    register_host
    generate_hosts_file
    install_hosts
    commit_changes
    
    # Set up cron job if requested
    if [ "$AUTO_SYNC" = true ]; then
        setup_cron
    fi
    
    log_step "All Done!"
    log_info "This host is now registered in your dotfiles"
    log_info "You can now SSH to any registered host using just its hostname"
    log_info "Example: ssh $SANITIZED_HOSTNAME"
    echo ""
    log_info "On each new machine, after running bootstrap.sh, you can run:"
    log_info "  $DOTFILES_DIR/hosts_manager.sh"
    log_info "to register that machine and get access to all other registered hosts"
    
    if [ "$AUTO_SYNC" = true ]; then
        echo ""
        log_info "Automatic sync has been set up. Your hosts will stay updated daily."
    else
        echo ""
        log_info "To enable automatic sync via cron, run:"
        log_info "  $0 --auto-sync"
    fi
}

# Run the main function
main "$@"