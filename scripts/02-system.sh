#!/bin/bash
set -euo pipefail

# System Setup - Updates and Essential Packages

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

log "Starting system setup..."

# Update package lists
log "Updating package lists..."
apt-get update -qq

# Upgrade existing packages
log "Upgrading system packages..."
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq

# Install essential packages
log "Installing essential packages..."
ESSENTIAL_PACKAGES=(
    # Core utilities
    curl
    wget
    git
    htop
    vim
    nano
    unzip
    software-properties-common
    apt-transport-https
    ca-certificates
    gnupg
    lsb-release
    jq
    net-tools
    dnsutils
    
    # System tools
    mc              # Midnight Commander file manager
    lsof            # List open files
    tmux            # Terminal multiplexer
    screen          # Terminal multiplexer (alternative)
    
    # Python
    python3
    python3-pip
    python3-venv
    python3-virtualenv
    
    # Build essentials
    build-essential
    
    # Modern CLI tools
    neovim          # Modern vim
    zsh             # Better shell
    fzf             # Fuzzy finder
    bat             # Cat with syntax highlighting
    ripgrep         # Fast grep
)

for pkg in "${ESSENTIAL_PACKAGES[@]}"; do
    # Skip comments
    [[ "$pkg" =~ ^# ]] && continue
    
    if ! dpkg -l | grep -q "^ii  $pkg "; then
        log "Installing $pkg..."
        DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$pkg" 2>/dev/null || {
            log "Warning: $pkg not available, skipping"
        }
    else
        log "$pkg already installed"
    fi
done

# Install eza (modern ls replacement) - from external repo
log "Installing eza (modern ls)..."
if ! command -v eza &> /dev/null; then
    mkdir -p /etc/apt/keyrings
    wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
    echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | tee /etc/apt/sources.list.d/gierens.list
    chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq eza || log "Warning: eza installation failed"
else
    log "eza already installed"
fi

# Enable unattended-upgrades for security patches
log "Configuring unattended-upgrades..."
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq unattended-upgrades

cat > /etc/apt/apt.conf.d/50unattended-upgrades <<EOF
Unattended-Upgrade::Allowed-Origins {
    "\${distro_id}:\${distro_codename}-security";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF

cat > /etc/apt/apt.conf.d/20auto-upgrades <<EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF

# Set timezone (optional, defaults to UTC)
log "Setting timezone to UTC..."
timedatectl set-timezone UTC

# Clean up
log "Cleaning up..."
apt-get autoremove -y -qq
apt-get autoclean -y -qq

# Setup bash aliases for modern tools
log "Setting up shell aliases..."
cat >> /root/.bashrc <<'ALIASEOF'

# Modern CLI tools aliases
alias ls='eza --icons --group-directories-first' 2>/dev/null || alias ls='ls --color=auto'
alias ll='eza -la --icons --group-directories-first' 2>/dev/null || alias ll='ls -alF'
alias la='eza -a --icons' 2>/dev/null || alias la='ls -A'
alias lt='eza --tree --level=2 --icons' 2>/dev/null || alias lt='tree -L 2'
alias cat='batcat' 2>/dev/null || alias cat='cat'
alias grep='rg' 2>/dev/null || alias grep='grep --color=auto'
alias vim='nvim' 2>/dev/null || alias vim='vim'
alias vi='nvim' 2>/dev/null || alias vi='vi'

# Git aliases (oh-my-zsh style)
alias g='git'
alias ga='git add'
alias gaa='git add --all'
alias gb='git branch'
alias gc='git commit -v'
alias gc!='git commit -v --amend'
alias gca='git commit -v -a'
alias gca!='git commit -v -a --amend'
alias gcl='git clone --recurse-submodules'
alias gco='git checkout'
alias gd='git diff'
alias gf='git fetch'
alias gfa='git fetch --all --prune'
alias gl='git pull'
alias gp='git push'
alias gst='git status'
alias glog='git log --oneline --decorate --graph'
alias gloga='git log --oneline --decorate --graph --all'

# Docker shortcuts
alias d='docker'
alias dc='docker compose'
alias dps='docker ps'
alias dlog='docker logs -f'

# System shortcuts
alias update='apt update && apt upgrade -y'
alias ports='netstat -tulanp'
alias meminfo='free -m -l -t'
alias psmem='ps auxf | sort -nr -k 4 | head -10'
alias pscpu='ps auxf | sort -nr -k 3 | head -10'
ALIASEOF

# Copy aliases to sudo user if exists
if [ -n "${SUDO_USER:-}" ]; then
    SUDO_HOME=$(eval echo ~$SUDO_USER)
    cat >> "$SUDO_HOME/.bashrc" <<'ALIASEOF'

# Modern CLI tools aliases
alias ls='eza --icons --group-directories-first' 2>/dev/null || alias ls='ls --color=auto'
alias ll='eza -la --icons --group-directories-first' 2>/dev/null || alias ll='ls -alF'
alias la='eza -a --icons' 2>/dev/null || alias la='ls -A'
alias lt='eza --tree --level=2 --icons' 2>/dev/null || alias lt='tree -L 2'
alias cat='batcat' 2>/dev/null || alias cat='cat'
alias grep='rg' 2>/dev/null || alias grep='grep --color=auto'
alias vim='nvim' 2>/dev/null || alias vim='vim'
alias vi='nvim' 2>/dev/null || alias vi='vi'

# Git aliases (oh-my-zsh style)
alias g='git'
alias ga='git add'
alias gaa='git add --all'
alias gb='git branch'
alias gc='git commit -v'
alias gc!='git commit -v --amend'
alias gca='git commit -v -a'
alias gca!='git commit -v -a --amend'
alias gcl='git clone --recurse-submodules'
alias gco='git checkout'
alias gd='git diff'
alias gf='git fetch'
alias gfa='git fetch --all --prune'
alias gl='git pull'
alias gp='git push'
alias gst='git status'
alias glog='git log --oneline --decorate --graph'
alias gloga='git log --oneline --decorate --graph --all'

# Docker shortcuts
alias d='docker'
alias dc='docker compose'
alias dps='docker ps'
alias dlog='docker logs -f'

# System shortcuts
alias update='apt update && apt upgrade -y'
alias ports='netstat -tulanp'
alias meminfo='free -m -l -t'
alias psmem='ps auxf | sort -nr -k 4 | head -10'
alias pscpu='ps auxf | sort -nr -k 3 | head -10'
ALIASEOF
fi

# Setup oh-my-zsh and change default shell to zsh
log "Installing oh-my-zsh..."
if [ ! -d /root/.oh-my-zsh ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    # Change to agnoster theme
    sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="agnoster"/' /root/.zshrc
    chsh -s /bin/zsh root

    # Add terminal compatibility, locale settings, and key bindings
    cat >> /root/.zshrc <<'ZSHEOF'

# Terminal and locale configuration
# Fix terminal compatibility (for Ghostty and other modern terminals)
if [[ $TERM == "xterm-ghostty" || $TERM == "ghostty" ]]; then
    export TERM=xterm-256color
fi

# Ensure true color support
export COLORTERM=truecolor

# Locale settings
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Fix backspace and delete keys (safeguard)
bindkey '^?' backward-delete-char
bindkey '^H' backward-delete-char
bindkey '^[[3~' delete-char
ZSHEOF

    log "oh-my-zsh installed for root, default shell changed to zsh"
else
    log "oh-my-zsh already installed"
fi

# Setup oh-my-zsh for sudo user if exists
if [ -n "${SUDO_USER:-}" ]; then
    SUDO_HOME=$(eval echo ~$SUDO_USER)
    if [ ! -d "$SUDO_HOME/.oh-my-zsh" ]; then
        sudo -u "$SUDO_USER" sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
        # Change to agnoster theme
        sudo -u "$SUDO_USER" sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="agnoster"/' "$SUDO_HOME/.zshrc"
        chsh -s /bin/zsh "$SUDO_USER"

        # Add terminal compatibility, locale settings, and key bindings
        sudo -u "$SUDO_USER" tee -a "$SUDO_HOME/.zshrc" > /dev/null <<'ZSHEOF'

# Terminal and locale configuration
# Fix terminal compatibility (for Ghostty and other modern terminals)
if [[ $TERM == "xterm-ghostty" || $TERM == "ghostty" ]]; then
    export TERM=xterm-256color
fi

# Ensure true color support
export COLORTERM=truecolor

# Locale settings
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Fix backspace and delete keys (safeguard)
bindkey '^?' backward-delete-char
bindkey '^H' backward-delete-char
bindkey '^[[3~' delete-char
ZSHEOF

        log "oh-my-zsh installed for $SUDO_USER, default shell changed to zsh"
    fi
fi

# Ensure locale is generated
log "Ensuring en_US.UTF-8 locale is available..."
if ! locale -a | grep -q "en_US.utf8"; then
    locale-gen en_US.UTF-8 2>/dev/null || log "Warning: Could not generate locale"
else
    log "Locale en_US.UTF-8 already available"
fi

log "System setup completed successfully"
