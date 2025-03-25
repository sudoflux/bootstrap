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
FORCE_SSH_CONFIG=false
SKIP_PULL_PHASE=false
DISTRIBUTE_KEYS=false

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Paths
DOTFILES_DIR="$HOME/dotfiles"
HOSTS_DIR="$DOTFILES_DIR/ssh_hosts"
HOSTS_FILE="$DOTFILES_DIR/ssh_hosts/hosts"
SSH_CONFIG="$HOME/.ssh/config"
SCRIPT_PATH="$DOTFILES_DIR/hosts_manager.sh"
SCRIPT_URL="https://raw.githubusercontent.com/sudoflux/bootstrap/main/hosts_manager.sh"
GITIGNORE_PATH="$DOTFILES_DIR/.gitignore"

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
            -f|--force-ssh-config)
                FORCE_SSH_CONFIG=true
                shift
                ;;
            --skip-pull-phase)
                SKIP_PULL_PHASE=true
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
            --distribute-keys)
                DISTRIBUTE_KEYS=true
                shift
                ;;
            -h|--help)
                echo "Usage: $0 [options]"
                echo ""
                echo "Options:"
                echo "  -v, --verbose       Enable verbose output"
                echo "  -u, --update-only   Only update hosts from repository (don't register this host)"
                echo "  -a, --auto-sync     Set up a daily cron job to keep hosts in sync"
                echo "  -f, --force-ssh-config  Force updating the SSH config even if it seems to be included"
                echo "  --skip-pull-phase   Skip the initial pull-only phase (not recommended)"
                echo "  --setup-cron        Set up cron job only (no other actions)"
                echo "  --remove-cron       Remove the auto-sync cron job"
                echo "  --distribute-keys    Copy SSH public key to all registered hosts"
                echo "  -h, --help          Show help message"
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

# Function to distribute SSH keys to registered hosts
distribute_ssh_keys() {
    log_step "Distributing SSH keys to registered hosts"
    
    # Check if SSH public key exists
    if [ ! -f "$HOME/.ssh/id_ed25519.pub" ]; then
        log_error "SSH public key not found at $HOME/.ssh/id_ed25519.pub"
        log_error "Please run bootstrap.sh first to generate SSH keys"
        return 1
    fi
    
    # Get current hostname for skipping
    CURRENT_HOST=$(hostname)
    CURRENT_HOST_SANITIZED=$(echo "$CURRENT_HOST" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]-')
    
    # Initialize counters
    local success_count=0
    local failed_hosts=()
    
    # Process each host configuration file
    for host_file in "$HOSTS_DIR"/*.conf; do
        if [ -f "$host_file" ]; then
            log_debug "Processing host file: $host_file"
            
            # Extract hostname, username, and IP from config
            local hostname=$(grep "^Host " "$host_file" | head -n1 | awk '{print $2}')
            local username=$(grep "User " "$host_file" | head -n1 | awk '{print $2}')
            local ip=$(grep "HostName " "$host_file" | head -n1 | awk '{print $2}')
            
            log_debug "Found host: $hostname (user: $username, ip: $ip)"
            
            # Skip current host
            if [ "$hostname" = "$CURRENT_HOST_SANITIZED" ]; then
                log_info "Skipping current host: $hostname"
                continue
            fi
            
            # Attempt to copy SSH key
            log_info "Copying SSH key to $username@$hostname ($ip)..."
            
            if command -v ssh-copy-id &> /dev/null; then
                # Use ssh-copy-id if available
                if ssh-copy-id -i "$HOME/.ssh/id_ed25519.pub" "$username@$ip"; then
                    log_info "Successfully copied key to $hostname"
                    success_count=$((success_count + 1))
                else
                    log_error "Failed to copy key to $hostname"
                    failed_hosts+=("$hostname")
                fi
            else
                # Alternative method if ssh-copy-id is not available
                if cat "$HOME/.ssh/id_ed25519.pub" | ssh "$username@$ip" "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"; then
                    log_info "Successfully copied key to $hostname"
                    success_count=$((success_count + 1))
                else
                    log_error "Failed to copy key to $hostname"
                    failed_hosts+=("$hostname")
                fi
            fi
        fi
    done
    
    # Summary
    echo ""
    log_step "Key Distribution Summary"
    log_info "Successfully copied keys to $success_count hosts"
    
    if [ ${#failed_hosts[@]} -gt 0 ]; then
        log_warn "Failed to copy keys to ${#failed_hosts[@]} hosts:"
        for host in "${failed_hosts[@]}"; do
            log_warn "  - $host"
        done
        echo ""
        log_info "To manually copy keys to failed hosts, use:"
        log_info "  ssh-copy-id -i ~/.ssh/id_ed25519.pub username@hostname"
        log_info "or:"
        log_info "  cat ~/.ssh/id_ed25519.pub | ssh username@hostname \"mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys\""
        return 1
    fi
    
    return 0
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
    migrate_from_old_path
    
    # Handle key distribution if requested
    if [ "$DISTRIBUTE_KEYS" = true ]; then
        distribute_ssh_keys
        exit $?
    fi
    
    # Run two-phase sync to prevent conflicts (unless in update-only mode)
    if [ "$UPDATE_ONLY" != true ]; then
        two_phase_sync
    else
        log_info "Running in update-only mode, skipping host registration"
    fi
    
    # Normal sync flow continues
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
    log_info "  $SCRIPT_PATH"
    log_info "to register that machine and get access to all other registered hosts"
    
    if [ "$AUTO_SYNC" = true ]; then
        echo ""
        log_info "Automatic sync has been set up. Your hosts will stay updated daily."
    else
        echo ""
        log_info "To enable automatic sync via cron, run:"
        log_info "  $SCRIPT_PATH --auto-sync"
    fi
    
    # Show additional help hints
    show_help_hints
}

# Run the main function
main "$@"