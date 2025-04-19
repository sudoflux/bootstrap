#!/usr/bin/env bash
#
# System Bootstrap Script
#  - Installs essential tools (curl, git, build tools, python3, pip, openssh-server)
#  - Ensures Neovim ≥ 0.9 via the neovim-ppa/unstable channel
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
detect_os

# ─── Install essential packages (excl. Neovim) ─────────────────────────────────
install_packages() {
  step "Installing essential packages"
  case "$OS_TYPE" in
    linux)
      case "$DISTRO" in
        ubuntu|debian)
          sudo apt-get update -qq
          sudo apt-get install -y \
            curl git build-essential python3 python3-pip \
            openssh-server
          ;;
        fedora|centos|rhel)
          sudo dnf install -y \
            curl git gcc gcc-c++ make python3 python3-pip \
            openssh-server
          ;;
        arch)
          sudo pacman -Sy --noconfirm \
            curl git base-devel python python-pip openssh
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
      brew install curl git python3 openssh neovim
      ;;
    windows)
      warn "On Windows, please install Git, Python, OpenSSH Server, and Neovim manually."
      ;;
  esac
  log "Essential packages installed"
}

# ─── Add unstable PPA & install/up‑date Neovim ≥ 0.9 ───────────────────────────
install_neovim() {
  step "Installing/upgrading Neovim via ppa:neovim-ppa/unstable"
  if [[ "$OS_TYPE" = "linux" && ( "$DISTRO" = "ubuntu" || "$DISTRO" = "debian" ) ]]; then
    sudo apt-get update -qq
    sudo apt-get install -y software-properties-common
    sudo add-apt-repository -y ppa:neovim-ppa/unstable
    sudo apt-get update -qq
    sudo apt-get install -y neovim
    log "Neovim now at $(nvim --version | head -n1 | awk '{print $2}')"
  else
    warn "Automatic Neovim upgrade only implemented for Debian/Ubuntu"
  fi
}

# ─── Ensure Neovim ≥ 0.9.0 ─────────────────────────────────────────────────────
ensure_neovim() {
  step "Ensuring Neovim ≥ 0.9.0"
  if command -v nvim &>/dev/null; then
    raw_ver=$(nvim --version | head -n1 | awk '{print $2}')
    ver=${raw_ver#v}  # strip leading 'v'
    if dpkg --compare-versions "$ver" lt "0.9.0"; then
      log "Detected Neovim $ver < 0.9.0 → upgrading"
      install_neovim
    else
      debug "Neovim $ver is OK"
    fi
  else
    log "Neovim not found → installing"
    install_neovim
  fi
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
    git fetch --all
    git reset --hard origin/main
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
  install_packages
  ensure_neovim
  setup_ssh_keys
  setup_dotfiles
  enable_sshd
  configure_dns_search

  echo
  log "Bootstrap complete! 🎉"
  log "Next steps:"
  log "- Add ~/.ssh/github_ed25519.pub to your GitHub account"
  log "- Reopen your shell so Neovim ≥0.9 is on your PATH"
}

main
