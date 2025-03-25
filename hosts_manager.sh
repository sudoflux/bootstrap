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