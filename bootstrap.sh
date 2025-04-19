#!/usr/bin/env bash
#
# System Bootstrap Script
#  - Installs essential tools (curl, git, build tools, python3, pip, openssh-server, node.js)
#  - Ensures Neovim ≥ 0.9 via the neovim-ppa/unstable channel
#  - Ensures Node.js (latest LTS)
#  - Sets up SSH keys & config for outgoing
#  - Clones/updates your dotfiles & runs install_dotfiles.sh
#  - Enables SSH server for incoming
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

# ─── Color Logging ────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log()    { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()   { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()  { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
step()   { echo -e "${BLUE}[STEP]${NC} $1"; }
debug()  { $VERBOSE && echo -e "[DEBUG] $1"; }

# ─── Parse Arguments ──────────────────────────────────────────────────────────
while (( "$#" )); do
  case "$1" in
    -v|--verbose) VERBOSE=true; shift ;;
    -f|--force)   FORCE=true; shift ;;
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
  -v, --verbose      Enable verbose logging
  -f, --force        Force reinstall/update of packages
  -d, --domain <dom> Configure DNS search domain (default: lab)
  -h, --help         Show this help
EOF
      exit 0
      ;;
    *) error "Unknown option: $1" ;;
  esac
done

# ─── Sudo up front ────────────────────────────────────────────────────────────
sudo -v

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

detect_os

# ─── Install essential packages (excl. Neovim & Node.js) ──────────────────────
install_packages() {
  step "Installing essential packages"
  if is_wsl; then
    debug "Running under WSL: installing packages as for $DISTRO"
  fi
  case "$OS_TYPE" in
    linux)
      case "$DISTRO" in
        ubuntu|debian)
          sudo apt-get update -qq
          sudo apt-get install -y \
            curl git build-essential python3 python3-pip \
            openssh-server unzip
          ;;
        fedora|centos|rhel)
          # Try dnf, fallback to yum for older systems
          if command -v dnf &>/dev/null; then
            sudo dnf install -y \
              curl git gcc gcc-c++ make python3 python3-pip \
              openssh-server unzip
          else
            sudo yum install -y \
              curl git gcc gcc-c++ make python3 python3-pip \
              openssh-server unzip
          fi
          ;;
        arch)
          sudo pacman -Sy --noconfirm \
            curl git base-devel python python-pip openssh unzip
          ;;
        *)
          warn "Please manually install: curl, git, compiler tools, python3, pip, openssh-server"
          ;;
      esac
      ;;
    macos)
      if ! command -v brew &>/dev/null; then
        step "Installing Homebrew"
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      fi
      brew update
      brew install curl git python3 openssh neovim node
      ;;
    windows)
      warn "On Windows, please install Git, Python, OpenSSH Server, Node.js, and Neovim manually."
      ;;
  esac
  log "Essential packages installed"
}

# ─── Ensure Node.js (version 20.x) ────────────────────────────────────────────
ensure_node() {
  step "Ensuring Node.js (version 20.x)"

  # Check for NVM first
  NVM_DIR="$HOME/.nvm"
  if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    log "NVM detected. Attempting to install/use Node.js 20 via NVM."
    # Source nvm script to make nvm command available
    \. "$NVM_DIR/nvm.sh" --no-use # Load nvm

    # Check current NVM version
    CURRENT_NVM_NODE=$(nvm current)
    NODE_MAJOR="" # Initialize NODE_MAJOR
    if [[ "$CURRENT_NVM_NODE" != "none" ]] && [[ "$CURRENT_NVM_NODE" != "system" ]]; then
        # Parse version like v18.20.8
        NODE_MAJOR=$(echo "$CURRENT_NVM_NODE" | sed 's/^v//' | cut -d. -f1)
    fi

    log "NVM current version: $CURRENT_NVM_NODE"

    # Check if NODE_MAJOR is a number and >= 20
    if [[ "$NODE_MAJOR" =~ ^[0-9]+$ ]] && (( NODE_MAJOR >= 20 )); then
        log "NVM Node.js version ($CURRENT_NVM_NODE) is sufficient (>= 20)"
        # Ensure it's the default
        nvm alias default 20 > /dev/null 2>&1 || nvm alias default system > /dev/null 2>&1 # Try setting default
        log "Set Node 20.x as default via NVM."
        return
    fi

    log "Installing Node.js 20.x via NVM..."
    nvm install 20 || error "NVM failed to install Node.js 20"
    log "Setting Node.js 20.x as default via NVM..."
    nvm alias default 20 || error "NVM failed to set default alias to 20"
    log "Switching current shell to use Node.js 20.x via NVM..."
    nvm use default > /dev/null # Use the newly set default

    # Verify
    hash -r
    FINAL_NODE_VERSION=$(node --version 2>/dev/null)
    log "Node.js version after NVM install: ${FINAL_NODE_VERSION:-'command failed'}"
    FINAL_NODE_MAJOR=$(echo "$FINAL_NODE_VERSION" | sed 's/^v//' | cut -d. -f1)
     if [[ -z "$FINAL_NODE_MAJOR" ]] || ! [[ "$FINAL_NODE_MAJOR" =~ ^[0-9]+$ ]] || (( FINAL_NODE_MAJOR < 20 )); then
         warn "NVM Node.js version is still not >= 20 after installation attempt!"
         warn "You may need to reload your shell profile (e.g., source ~/.bashrc) or restart your terminal."
     fi
     return # NVM handled it, skip system install
  fi

  # --- Fallback to System Installation (NodeSource) if NVM not found ---
  log "NVM not detected. Proceeding with system-wide Node.js installation via NodeSource."

  if [[ "$OS_TYPE" = "linux" ]]; then
    # Remove any existing nodejs/npm from apt to avoid conflicts ONLY if NVM wasn't found
    if [[ "$DISTRO" == "ubuntu" || "$DISTRO" == "debian" ]]; then
      log "Attempting to remove existing Node.js/npm from apt..."
      sudo apt-get remove -y nodejs npm nodejs-dev || true
      sudo apt-get autoremove -y || true
    fi

    # Check system node version (should be none now or irrelevant)
    NODE_PATH=$(command -v node || echo "not_found")
    if [[ "$NODE_PATH" != "not_found" && ! "$NODE_PATH" =~ \.nvm ]]; then # Check it's not an NVM path somehow
      CURRENT_NODE=$(node --version 2>/dev/null | sed 's/^v//')
      NODE_MAJOR=$(echo "$CURRENT_NODE" | cut -d. -f1)
      log "System Node.js currently installed: v${CURRENT_NODE:-unknown} at $NODE_PATH"
      if [[ -n "$NODE_MAJOR" ]] && (( NODE_MAJOR >= 20 )); then
        log "System Node.js version is sufficient (>= 20)"
        return
      fi
      log "System Node.js version is < 20 or unknown. Attempting upgrade/install."
    else
      log "System Node.js not found or is NVM path, installing Node.js 20.x via package manager."
    fi

    # Use the correct NodeSource script for the distro
    case "$DISTRO" in
      ubuntu|debian)
        log "Setting up NodeSource repository for Node.js 20.x..."
        curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
        log "Updating package list after adding NodeSource repo..."
        sudo apt-get update -qq
        log "Installing Node.js from NodeSource..."
        sudo apt-get install -y nodejs
        ;;
      fedora|centos|rhel)
        log "Setting up NodeSource repository for Node.js 20.x..."
        curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -
        log "Installing Node.js from NodeSource..."
        if command -v dnf &>/dev/null; then
          sudo dnf install -y nodejs
        else
          sudo yum install -y nodejs
        fi
        ;;
      *)
        warn "Automatic Node.js 20.x install not supported for $DISTRO. Please install manually."
        return # Skip final check if install wasn't attempted
        ;;
    esac

    # Force hash table refresh and check final version/path
    hash -r
    NODE_PATH_AFTER=$(command -v node || echo "not_found")
    if [[ "$NODE_PATH_AFTER" != "not_found" ]]; then
        FINAL_NODE_VERSION=$(node --version 2>/dev/null)
        log "Node.js path after install: $NODE_PATH_AFTER"
        log "Node.js version after install: ${FINAL_NODE_VERSION:-'command failed'}"
        # Final verification
        FINAL_NODE_MAJOR=$(echo "$FINAL_NODE_VERSION" | sed 's/^v//' | cut -d. -f1)
        if [[ -n "$FINAL_NODE_MAJOR" ]] && (( FINAL_NODE_MAJOR < 20 )); then
             warn "Node.js version is still < 20 after installation attempt!"
        fi
    else
        error "Node.js command not found after installation attempt!"
    fi

  elif [[ "$OS_TYPE" = "macos" ]]; then
    if ! brew list node &>/dev/null; then
      brew install node
    else
      brew upgrade node
    fi
    log "Node.js version: $(node --version)"
  fi
}

# ─── install_neovim ──────────────────────────────────────────────────────────
install_neovim() {
  step "Installing/upgrading Neovim via ppa:neovim-ppa/unstable"
  sudo apt-get update -qq
  sudo apt-get install -y software-properties-common
  sudo add-apt-repository -y ppa:neovim-ppa/unstable
  sudo apt-get update -qq
  sudo apt-get install -y neovim
  log "Neovim now at $(nvim --version | head -n1 | awk '{print $2}')"
}

# ─── ensure_neovim ────────────────────────────────────────────────────────────
ensure_neovim() {
  step "Ensuring Neovim ≥ 0.9.0"
  if command -v nvim &>/dev/null; then
    raw_ver=$(nvim --version | head -n1 | awk '{print $2}')
    # Extract major and minor version numbers only
    major_ver=$(echo "$raw_ver" | sed 's/^v//' | cut -d. -f1)
    minor_ver=$(echo "$raw_ver" | sed 's/^v//' | cut -d. -f2)
    
    echo "DEBUG: raw_ver=$raw_ver"
    echo "DEBUG: major_ver=$major_ver"
    echo "DEBUG: minor_ver=$minor_ver"
    
    if [ "$major_ver" -gt 0 ] || [ "$minor_ver" -ge 9 ]; then
      debug "Neovim $raw_ver is already ≥ 0.9.0"
      echo "DEBUG: Version check passed, continuing..."
      return 0
    else
      log "Detected Neovim $raw_ver < 0.9.0 → upgrading"
      install_neovim
    fi
  else
    log "Neovim not found → installing"
    install_neovim
  fi
  echo "DEBUG: ensure_neovim completed"
}

# ─── SSH Keys & Config (outgoing) ─────────────────────────────────────────────
setup_ssh_keys() {
  step "Setting up SSH keys & config"
  mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"

  # GitHub key
  if [[ ! -f "$HOME/.ssh/github_ed25519" ]]; then
    log "Generating GitHub SSH key"
    ssh-keygen -t ed25519 -C "$(whoami)@$(hostname)" -f "$HOME/.ssh/github_ed25519" -N ""
    echo "Add to GitHub:" && cat "$HOME/.ssh/github_ed25519.pub"
  fi

  # Default key
  if [[ ! -f "$HOME/.ssh/id_ed25519" ]]; then
    log "Generating default SSH key"
    ssh-keygen -t ed25519 -f "$HOME/.ssh/id_ed25519" -N ""
  fi

  # Write ~/.ssh/config
  {
    echo "Host github.com"
    echo "  User git"
    echo "  IdentityFile ~/.ssh/github_ed25519"
    echo "  AddKeysToAgent yes"
    echo ""
    echo "Host *"
    echo "  IdentityFile ~/.ssh/id_ed25519"
    echo "  AddKeysToAgent yes"
  } >> "$HOME/.ssh/config"

  chmod 600 "$HOME/.ssh/config"
  log "SSH keys and config ready"
}

# ─── Clone/Update Dotfiles & Run Installer ────────────────────────────────────
setup_dotfiles() {
  step "Cloning/updating dotfiles"
  if [[ -d "$HOME/dotfiles/.git" ]]; then
    cd "$HOME/dotfiles"
    git fetch --all --prune

    # reset to whatever branch origin/HEAD points to
    git reset --hard origin/HEAD
  else
    rm -rf "$HOME/dotfiles"
    git clone https://github.com/sudoflux/dotfiles.git "$HOME/dotfiles"
  fi

  step "Running dotfiles installer"
  chmod +x "$HOME/dotfiles/install_dotfiles.sh"
  "$HOME/dotfiles/install_dotfiles.sh"
}


# ─── Enable SSH Server (incoming) ─────────────────────────────────────────────
enable_sshd() {
  step "Enabling SSH server"
  if is_wsl; then
    warn "WSL detected: Skipping SSH server enablement (systemd not available)"
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

# ─── Main ────────────────────────────────────────────────────────────────────
main() {
  set +e  # Don't exit on error
  install_packages
  ensure_node
  ensure_neovim || true  # Continue even if ensure_neovim returns non-zero
  setup_ssh_keys
  setup_dotfiles
  enable_sshd
  configure_dns_search
  set -e  # Restore exit on error

  echo
  log "Bootstrap complete! 🎉"
  log "Next steps:"
  log "- Add ~/.ssh/github_ed25519.pub to your GitHub account"
  log "- Reopen your shell so Neovim ≥0.9 is on your PATH"
}

main
