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
          sudo dnf install -y \
            curl git gcc gcc-c++ make python3 python3-pip \
            openssh-server unzip
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

# ─── Ensure Node.js (latest LTS) ──────────────────────────────────────────────
ensure_node() {
  step "Ensuring Node.js (latest LTS)"
  if [[ "$OS_TYPE" = "linux" ]]; then
    # Check if node is installed and version is current LTS
    if command -v node &>/dev/null; then
      CURRENT_NODE=$(node --version | sed 's/^v//')
      log "Node.js currently installed: v$CURRENT_NODE"
    else
      log "Node.js not found, installing latest LTS"
      # NodeSource setup for latest LTS
      curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
      sudo apt-get install -y nodejs
      return
    fi
    # Always update to latest LTS
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    sudo apt-get install -y nodejs
    log "Node.js updated to: $(node --version)"
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
