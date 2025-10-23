# VPS Bootstrap

Automated VPS setup for Ubuntu 24.04 LTS with security hardening, Docker, and monitoring.

## Supported Systems

- **Ubuntu 24.04 LTS** (primary and only supported distro)

## Features

- System updates and essential packages
- **Development tools**: mc, tmux, neovim, Python (pip, venv)
- **Modern CLI tools**: eza, fzf, bat, ripgrep
- **Shell**: zsh with oh-my-zsh (agnoster theme) set as default
- **Shell enhancements**: git aliases (oh-my-zsh style), Docker shortcuts, system monitoring
- Security hardening (UFW firewall, fail2ban, SSH hardening)
- Docker + Docker Compose installation
- SOPS + Age for secrets management
- Monitoring with Discord notifications (disk alerts, uptime)

## Quick Start

### Prerequisites

**IMPORTANT:** When creating your VPS, make sure to add your SSH key during setup. This is required for secure access.

If you don't have an SSH key:
```bash
# Generate SSH key on your local machine
ssh-keygen -t ed25519 -C "your_email@example.com"

# Copy public key (add this to VPS during creation)
cat ~/.ssh/id_ed25519.pub
```

**SECURITY NOTE:** The setup will:
1. Create a new sudo user (you'll be prompted for username)
2. Copy your SSH keys from root to the new user
3. Disable root login via SSH
4. Disable password authentication (SSH keys only)

### Installation

```bash
# SSH to your VPS
ssh root@YOUR_VPS_IP

# Clone repo from GitHub
git clone https://github.com/yourusername/vps-bootstrap.git
cd vps-bootstrap

# Make scripts executable
chmod +x setup.sh scripts/*.sh

# Run setup (requires sudo)
# You'll be prompted for a username for the new sudo user
sudo ./setup.sh

# Or set username via environment variable
export VPS_USERNAME="yourusername"
sudo ./setup.sh

# Optional: with Discord notifications
export DISCORD_WEBHOOK="https://discord.com/api/webhooks/YOUR_WEBHOOK"
export VPS_USERNAME="yourusername"
sudo ./setup.sh
```

**CRITICAL:** After setup completes, test SSH login as the new user in a separate terminal BEFORE closing your root session:
```bash
# In a NEW terminal window (keep root session open!)
ssh yourusername@YOUR_VPS_IP

# If login works, you can safely exit root session
# If login fails, fix issues while still connected as root
```

## What Gets Installed

0. **User Setup**:
   - New sudo user with SSH keys copied from root
   - Passwordless sudo access
   - Password authentication disabled
1. **System packages**:
   - Core: curl, wget, git, htop, vim, nano, jq
   - Tools: mc, lsof, tmux, screen
   - Python: python3, pip, venv, virtualenv
   - Modern CLI: neovim, zsh, fzf, bat, ripgrep, eza
2. **Security**:
   - UFW firewall (ports 22, 80, 443)
   - fail2ban (SSH brute-force protection)
   - SSH hardening: root login disabled, password auth disabled, SSH keys only
3. **Docker**: Latest Docker Engine + Docker Compose v2
4. **SOPS**: Secrets encryption with Age
5. **Monitoring**: Disk space alerts via Discord webhook
6. **Shell**:
   - zsh with oh-my-zsh (agnoster theme) set as default
   - Git aliases (oh-my-zsh style): g, ga, gc, gco, gst, glog, etc.
   - Docker shortcuts: d, dc, dps, dlog
   - System monitoring aliases

## Configuration

Before running, optionally set:

```bash
# Username for new sudo user (optional, will prompt if not set)
export VPS_USERNAME="yourusername"

# Discord webhook for monitoring alerts (optional, monitoring skipped if not set)
export DISCORD_WEBHOOK="https://discord.com/api/webhooks/..."
```

## Post-Install

After successful setup:

1. **Test SSH login as new user in separate terminal** (CRITICAL - do this before closing root session!)
   ```bash
   ssh yourusername@YOUR_VPS_IP
   ```
2. **Logout and login again as new user** (new shell: zsh with oh-my-zsh)
3. Configure Age key: `~/.config/sops/age/keys.txt`
4. Test Discord alerts: `/opt/monitoring/test-notification.sh`
5. Test new aliases: `gst` (git status), `ll` (eza ls), `d ps` (docker ps)
6. Reboot recommended: `sudo reboot`

**IMPORTANT:** Root SSH login is now disabled. Always use your sudo user for SSH access.

## Files

```
vps-bootstrap/
├── setup.sh              # Main orchestrator
├── scripts/
│   ├── 00-user.sh        # User creation with sudo
│   ├── 01-system.sh      # System updates
│   ├── 02-security.sh    # Firewall, fail2ban, SSH hardening
│   ├── 03-docker.sh      # Docker installation
│   ├── 04-monitoring.sh  # Monitoring setup
│   └── 05-sops.sh        # SOPS + Age
└── config/
    ├── ufw.rules         # Firewall rules
    └── fail2ban.conf     # Fail2ban config
```

## Idempotent

Safe to re-run. Scripts check existing installations.

## License

MIT
