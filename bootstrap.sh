#!/usr/bin/env bash
#
# Minimal System Bootstrap Script
#  - Installs essential tools (curl, git, python3, openssh-server)
#  - Sets up SSH keys & config for outgoing connections
#  - Clones/updates your dotfiles & runs install_dotfiles.sh
#  - Enables SSH server for incoming connections
#  - Optionally configures a DNS search domain
#
# Usage: bootstrap.sh [-v|--verbose] [-f|--force] [-d|--domain <name>] [-h|--help]

set -euo pipefail
IFS=$'\n\t'

# ─── Configurable defaults ────────────────────────────────────────────────────
VERBOSE=false
FORCE=false
CONFIGURE_SEARCH_DOMAIN=false
SEARCH_DOMAIN="lab"
DRY_RUN=false
SKIP_PACKAGES=false
SKIP_DOTFILES=false
LOG_FILE=""
MAX_RETRIES=3
RETRY_DELAY=5

# ─── Detect actual user when run with sudo ────────────────────────────────────
if [[ -n "${SUDO_USER:-}" ]]; then
    ACTUAL_USER="$SUDO_USER"
    ACTUAL_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
else
    ACTUAL_USER="$USER"
    ACTUAL_HOME="$HOME"
fi

# ─── Color Logging ────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'; NC='\033[0m'

# Enhanced logging with timestamps and file output
log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] ${GREEN}[INFO]${NC} $1"
    echo -e "$msg"
    if [[ -n "$LOG_FILE" ]]; then
        echo -e "$msg" | sed 's/\x1b\[[0-9;]*m//g' >> "$LOG_FILE"
    fi
}

warn() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] ${YELLOW}[WARN]${NC} $1"
    echo -e "$msg"
    if [[ -n "$LOG_FILE" ]]; then
        echo -e "$msg" | sed 's/\x1b\[[0-9;]*m//g' >> "$LOG_FILE"
    fi
}

error() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] ${RED}[ERROR]${NC} $1"
    echo -e "$msg" >&2
    if [[ -n "$LOG_FILE" ]]; then
        echo -e "$msg" | sed 's/\x1b\[[0-9;]*m//g' >> "$LOG_FILE"
    fi
    exit 1
}

step() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] ${BLUE}[STEP]${NC} $1"
    echo -e "$msg"
    if [[ -n "$LOG_FILE" ]]; then
        echo -e "$msg" | sed 's/\x1b\[[0-9;]*m//g' >> "$LOG_FILE"
    fi
}

debug() {
    if $VERBOSE; then
        local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [DEBUG] $1"
        echo -e "$msg"
        if [[ -n "$LOG_FILE" ]]; then
            echo -e "$msg" >> "$LOG_FILE"
        fi
    fi
}

# ─── Parse Arguments ──────────────────────────────────────────────────────────
while (( "$#" )); do
  case "$1" in
    -v|--verbose) VERBOSE=true; shift ;;
    -f|--force)   FORCE=true; shift ;;
    --dry-run)    DRY_RUN=true; shift ;;
    --skip-packages) SKIP_PACKAGES=true; shift ;;
    --skip-dotfiles) SKIP_DOTFILES=true; shift ;;
    --log-file)
      LOG_FILE="$2"
      shift 2
      ;;
    -d|--domain)
      CONFIGURE_SEARCH_DOMAIN=true
      if [[ -n "${2-}" && "${2:0:1}" != "-" ]]; then
        SEARCH_DOMAIN="$2"; shift 2
      else
        shift
      fi
      ;;
    -h|--help)
      cat <<EOF
Usage: $0 [options]

Options:
  -v, --verbose         Enable verbose logging
  -f, --force          Force reinstall/update of packages
  --dry-run            Preview changes without applying them
  --skip-packages      Skip package installation
  --skip-dotfiles      Skip dotfiles setup
  --log-file <file>    Save logs to specified file
  -d, --domain <dom>   Configure DNS search domain (default: lab)
  -h, --help           Show this help
EOF
      exit 0
      ;;
    *) error "Unknown option: $1" ;;
  esac
done

# ─── Initialize logging ───────────────────────────────────────────────────────
if [[ -n "$LOG_FILE" ]]; then
    mkdir -p "$(dirname "$LOG_FILE")"
    echo "=== Bootstrap Started at $(date) ===" > "$LOG_FILE"
fi

# ─── Warn about root execution ────────────────────────────────────────────────
if [[ $EUID -eq 0 ]] && [[ -z "${SUDO_USER:-}" ]]; then
    warn "Running as root user. Dotfiles will be installed for root."
    warn "Consider running as a regular user or with sudo for user-specific setup."
elif [[ -n "${SUDO_USER:-}" ]]; then
    log "Running with sudo. Will install dotfiles for user: $ACTUAL_USER"
fi

# ─── Sudo up front ────────────────────────────────────────────────────────────
if ! $DRY_RUN && ! $SKIP_PACKAGES; then
    # Check if we already have sudo access or if we're running as root
    if [[ $EUID -eq 0 ]]; then
        debug "Running as root"
    elif ! sudo -n true 2>/dev/null; then
        # We need sudo but don't have it - check if we can prompt
        if [[ -t 0 ]]; then
            sudo -v
        else
            error "This script requires sudo access for package installation. Please run with sudo or ensure sudo is available."
        fi
    fi
fi

# ─── Detect OS ────────────────────────────────────────────────────────────────
detect_os() {
  step "Detecting operating system"
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    OS_TYPE="linux"; DISTRO="$ID"
    log "Linux distro: $DISTRO"
  elif [[ "$(uname)" == "Darwin" ]]; then
    OS_TYPE="macos"; DISTRO="macos"
    log "macOS detected"
  elif [[ "$(uname -s)" =~ MINGW ]]; then
    OS_TYPE="windows"; DISTRO="windows"
    log "Windows detected"
  else
    error "Unsupported OS"
  fi
}

# Add WSL detection
is_wsl() {
  grep -qi microsoft /proc/version 2>/dev/null
}

# ─── Prerequisites check ──────────────────────────────────────────────────────
check_prerequisites() {
  step "Checking prerequisites"
  
  # Check internet connectivity
  if ! curl -s --head --connect-timeout 5 https://github.com > /dev/null 2>&1; then
    error "No internet connection detected. Please check your network connection."
  fi
  log "Internet connectivity verified"
  
  # Check disk space (need at least 500MB free for minimal install)
  if [[ "$OS_TYPE" != "windows" ]]; then
    available_space=$(df -BM "$ACTUAL_HOME" | awk 'NR==2 {print $4}' | sed 's/M//')
    if [[ "$available_space" -lt 500 ]]; then
      error "Insufficient disk space. At least 500MB free space required."
    fi
    log "Disk space check passed: ${available_space}MB available"
  fi
}

# ─── Retry command helper ─────────────────────────────────────────────────────
retry_command() {
  local cmd="$1"
  local description="$2"
  local retries=0
  
  while (( retries < MAX_RETRIES )); do
    if eval "$cmd"; then
      return 0
    fi
    
    retries=$((retries + 1))
    if (( retries < MAX_RETRIES )); then
      warn "$description failed. Retrying in $RETRY_DELAY seconds... (attempt $((retries + 1))/$MAX_RETRIES)"
      sleep "$RETRY_DELAY"
    else
      error "$description failed after $MAX_RETRIES attempts"
    fi
  done
}

# ─── Install essential packages ───────────────────────────────────────────────
install_packages() {
  [[ "$SKIP_PACKAGES" == true ]] && { log "Skipping package installation"; return; }
  
  step "Installing essential packages"
  if is_wsl; then
    debug "Running under WSL: installing packages as for $DISTRO"
  fi
  
  if $DRY_RUN; then
    log "[DRY RUN] Would install: curl git python3 openssh-server"
    return
  fi
  
  case "$OS_TYPE" in
    linux)
      case "$DISTRO" in
        ubuntu|debian)
          sudo apt-get update -qq
          sudo apt-get install -y curl git python3 openssh-server
          ;;
        fedora|centos|rhel)
          # Try dnf, fallback to yum for older systems
          if command -v dnf &>/dev/null; then
            sudo dnf install -y curl git python3 openssh-server
          else
            sudo yum install -y curl git python3 openssh-server
          fi
          ;;
        arch)
          sudo pacman -Sy --noconfirm curl git python openssh
          ;;
        *)
          warn "Please manually install: curl, git, python3, openssh-server"
          ;;
      esac
      ;;
    macos)
      if ! command -v brew &>/dev/null; then
        step "Installing Homebrew"
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      fi
      brew update
      brew install curl git python3 openssh
      ;;
    windows)
      warn "On Windows, please install Git, Python, and OpenSSH Server manually."
      ;;
  esac
  log "Essential packages installed"
}

# ─── SSH Keys & Config (outgoing) ─────────────────────────────────────────────
setup_ssh_keys() {
  step "Setting up SSH keys & config"
  
  local ssh_dir="$ACTUAL_HOME/.ssh"
  
  if ! $DRY_RUN; then
    if [[ -n "${SUDO_USER:-}" ]]; then
      sudo -u "$ACTUAL_USER" mkdir -p "$ssh_dir"
      sudo -u "$ACTUAL_USER" chmod 700 "$ssh_dir"
    else
      mkdir -p "$ssh_dir" && chmod 700 "$ssh_dir"
    fi
  else
    log "[DRY RUN] Would create ~/.ssh directory"
  fi

  # GitHub key
  if [[ ! -f "$ssh_dir/github_ed25519" ]]; then
    log "Generating GitHub SSH key"
    if ! $DRY_RUN; then
      if [[ -n "${SUDO_USER:-}" ]]; then
        sudo -u "$ACTUAL_USER" ssh-keygen -t ed25519 -C "$ACTUAL_USER@$(hostname)" -f "$ssh_dir/github_ed25519" -N ""
        echo ""
        echo "================== IMPORTANT =================="
        echo "Add this SSH key to your GitHub account:"
        echo "https://github.com/settings/keys"
        echo ""
        cat "$ssh_dir/github_ed25519.pub"
        echo "==============================================="
        echo ""
      else
        ssh-keygen -t ed25519 -C "$(whoami)@$(hostname)" -f "$ssh_dir/github_ed25519" -N ""
        echo ""
        echo "================== IMPORTANT =================="
        echo "Add this SSH key to your GitHub account:"
        echo "https://github.com/settings/keys"
        echo ""
        cat "$ssh_dir/github_ed25519.pub"
        echo "==============================================="
        echo ""
      fi
    else
      log "[DRY RUN] Would generate GitHub SSH key"
    fi
  else
    debug "GitHub SSH key already exists"
  fi

  # Default key
  if [[ ! -f "$ssh_dir/id_ed25519" ]]; then
    log "Generating default SSH key"
    if ! $DRY_RUN; then
      if [[ -n "${SUDO_USER:-}" ]]; then
        sudo -u "$ACTUAL_USER" ssh-keygen -t ed25519 -f "$ssh_dir/id_ed25519" -N ""
      else
        ssh-keygen -t ed25519 -f "$ssh_dir/id_ed25519" -N ""
      fi
    else
      log "[DRY RUN] Would generate default SSH key"
    fi
  else
    debug "Default SSH key already exists"
  fi

  # Write ~/.ssh/config if it doesn't have our entries
  if ! grep -q "Host github.com" "$ssh_dir/config" 2>/dev/null; then
    log "Updating SSH config"
    if ! $DRY_RUN; then
      # Remove broken symlinks
      if [[ -L "$ssh_dir/config" && ! -e "$ssh_dir/config" ]]; then
        rm -f "$ssh_dir/config"
      fi
      local config_content=$(cat <<EOF
Host github.com
  User git
  IdentityFile ~/.ssh/github_ed25519
  AddKeysToAgent yes

Host *
  IdentityFile ~/.ssh/id_ed25519
  AddKeysToAgent yes
EOF
)
      if [[ -n "${SUDO_USER:-}" ]]; then
        sudo -u "$ACTUAL_USER" touch "$ssh_dir/config"
        echo "$config_content" | sudo -u "$ACTUAL_USER" tee -a "$ssh_dir/config" > /dev/null
        sudo -u "$ACTUAL_USER" chmod 600 "$ssh_dir/config"
      else
        touch "$ssh_dir/config"
        echo "$config_content" >> "$ssh_dir/config"
        chmod 600 "$ssh_dir/config"
      fi
    else
      log "[DRY RUN] Would update SSH config"
    fi
  else
    debug "SSH config already contains GitHub configuration"
  fi
  
  log "SSH keys and config ready"
}

# ─── Clone/Update Dotfiles & Run Installer ────────────────────────────────────
setup_dotfiles() {
  [[ "$SKIP_DOTFILES" == true ]] && { log "Skipping dotfiles setup"; return; }
  
  step "Cloning/updating dotfiles"
  local dotfiles_dir="$ACTUAL_HOME/dotfiles"
  
  if [[ -d "$dotfiles_dir/.git" ]]; then
    if ! $DRY_RUN; then
      cd "$dotfiles_dir"
      # Ensure we're using HTTPS for updates during bootstrap
      if [[ -n "${SUDO_USER:-}" ]]; then
        current_url=$(sudo -u "$ACTUAL_USER" git remote get-url origin)
        if [[ "$current_url" =~ ^git@ ]]; then
          log "Switching dotfiles to HTTPS for bootstrap"
          sudo -u "$ACTUAL_USER" git remote set-url origin https://github.com/sudoflux/dotfiles.git
        fi
        sudo -u "$ACTUAL_USER" git fetch --all --prune
        sudo -u "$ACTUAL_USER" git reset --hard origin/HEAD
      else
        current_url=$(git remote get-url origin)
        if [[ "$current_url" =~ ^git@ ]]; then
          log "Switching dotfiles to HTTPS for bootstrap"
          git remote set-url origin https://github.com/sudoflux/dotfiles.git
        fi
        retry_command "git fetch --all --prune" "Fetching dotfiles updates"
        git reset --hard origin/HEAD
      fi
    else
      log "[DRY RUN] Would update existing dotfiles"
    fi
  else
    if ! $DRY_RUN; then
      if [[ -n "${SUDO_USER:-}" ]]; then
        sudo -u "$ACTUAL_USER" rm -rf "$dotfiles_dir"
        sudo -u "$ACTUAL_USER" git clone https://github.com/sudoflux/dotfiles.git "$dotfiles_dir"
      else
        rm -rf "$dotfiles_dir"
        retry_command "git clone https://github.com/sudoflux/dotfiles.git '$dotfiles_dir'" "Cloning dotfiles repository"
      fi
    else
      log "[DRY RUN] Would clone dotfiles repository"
    fi
  fi

  step "Running dotfiles installer"
  if ! $DRY_RUN && [[ -f "$dotfiles_dir/install_dotfiles.sh" ]]; then
    if [[ -n "${SUDO_USER:-}" ]]; then
      sudo -u "$ACTUAL_USER" chmod +x "$dotfiles_dir/install_dotfiles.sh"
      cd "$dotfiles_dir" && sudo -u "$ACTUAL_USER" "$dotfiles_dir/install_dotfiles.sh"
    else
      chmod +x "$dotfiles_dir/install_dotfiles.sh"
      "$dotfiles_dir/install_dotfiles.sh"
    fi
  else
    log "[DRY RUN] Would run dotfiles installer"
  fi
}

# ─── Enable SSH Server (incoming) ─────────────────────────────────────────────
enable_sshd() {
  step "Enabling SSH server"
  if is_wsl; then
    warn "WSL detected: Skipping SSH server enablement (systemd not available)"
    return
  fi
  
  if $DRY_RUN; then
    log "[DRY RUN] Would enable SSH server"
    return
  fi
  
  if [[ "$OS_TYPE" = "linux" ]]; then
    case "$DISTRO" in
      ubuntu|debian) sudo systemctl enable --now ssh ;;
      fedora|centos|rhel|arch) sudo systemctl enable --now sshd ;;
    esac
    log "SSH server active"
  elif [[ "$OS_TYPE" = "macos" ]]; then
    sudo systemsetup -setremotelogin on
    log "Remote Login (SSH) enabled"
  fi
}

# ─── Optional: Configure DNS Search Domain ────────────────────────────────────
configure_dns_search() {
  [[ "$CONFIGURE_SEARCH_DOMAIN" == true ]] || return
  step "Configuring DNS search domain: $SEARCH_DOMAIN"

  if $DRY_RUN; then
    log "[DRY RUN] Would configure DNS search domain: $SEARCH_DOMAIN"
    return
  fi

  if command -v resolvectl &>/dev/null && systemctl is-active --quiet systemd-resolved; then
    iface=$(ip -o -4 route show to default | awk '{print $5}' | head -1)
    sudo resolvectl domain "$iface" "$SEARCH_DOMAIN"
    log "systemd-resolved domain set on $iface"
  else
    sudo cp /etc/resolv.conf /etc/resolv.conf.bak
    if grep -q "^search" /etc/resolv.conf; then
      sudo sed -i "s/^search.*/search $SEARCH_DOMAIN/" /etc/resolv.conf
    else
      echo "search $SEARCH_DOMAIN" | sudo tee -a /etc/resolv.conf
    fi
    log "/etc/resolv.conf updated"
  fi
}

# ─── Generate summary report ──────────────────────────────────────────────────
generate_report() {
    local report_file="$ACTUAL_HOME/.bootstrap-report-$(date +%Y%m%d_%H%M%S).txt"
    
    if ! $DRY_RUN; then
        cat > "$report_file" <<EOF
Bootstrap Summary Report
========================
Date: $(date)
Hostname: $(hostname)
User: $ACTUAL_USER
Home: $ACTUAL_HOME
OS: $OS_TYPE ($DISTRO)

Actions Performed:
------------------
EOF
    
        [[ "$SKIP_PACKAGES" != true ]] && echo "✓ Installed/updated system packages" >> "$report_file"
        [[ -f "$ACTUAL_HOME/.ssh/github_ed25519" ]] && echo "✓ Generated SSH keys" >> "$report_file"
        [[ -d "$ACTUAL_HOME/dotfiles" ]] && echo "✓ Set up dotfiles" >> "$report_file"
        [[ "$CONFIGURE_SEARCH_DOMAIN" == true ]] && echo "✓ Configured DNS search domain: $SEARCH_DOMAIN" >> "$report_file"
        
        cat >> "$report_file" <<EOF

SSH Keys:
---------
GitHub: $ACTUAL_HOME/.ssh/github_ed25519
Default: $ACTUAL_HOME/.ssh/id_ed25519

Next Steps:
-----------
1. Add GitHub SSH key to your account: https://github.com/settings/keys
2. Run hosts_manager.sh to set up host synchronization
3. Review the log file: ${LOG_FILE:-"No log file specified"}

EOF
        
        if [[ -n "${SUDO_USER:-}" ]]; then
            chown "$ACTUAL_USER:$ACTUAL_USER" "$report_file"
        fi
        
        log "Summary report saved to: $report_file"
        echo
        cat "$report_file"
    fi
}

# ─── Main ────────────────────────────────────────────────────────────────────
main() {
  log "Starting bootstrap process"
  local start_time=$SECONDS
  
  # Detect OS first
  detect_os
  
  # Pre-flight checks
  check_prerequisites
  
  # Main installation steps
  install_packages
  setup_ssh_keys
  setup_dotfiles
  enable_sshd
  configure_dns_search
  
  # Generate final report
  generate_report

  echo
  log "Bootstrap complete! 🎉"
  
  # Show quick stats
  local duration=$((SECONDS - start_time))
  log "Total time: $((duration / 60))m $((duration % 60))s"
  [[ -n "$LOG_FILE" ]] && log "Full log saved to: $LOG_FILE"
  
  if $DRY_RUN; then
    echo
    warn "This was a DRY RUN - no changes were made"
    warn "Run without --dry-run to apply changes"
  fi
}

main