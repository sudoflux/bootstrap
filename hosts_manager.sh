# Global variables
VERBOSE=false
AUTO_SYNC=false
UPDATE_ONLY=false
CRON_SETUP=false
CRON_UNINSTALL=false
FORCE_SSH_CONFIG=false
SKIP_PULL_PHASE=false
DISTRIBUTE_KEYS=false

// ... existing code ...

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

// ... existing code ...

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