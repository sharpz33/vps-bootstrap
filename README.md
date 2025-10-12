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
sudo ./setup.sh

# Optional: with Discord notifications
export DISCORD_WEBHOOK="https://discord.com/api/webhooks/YOUR_WEBHOOK"
sudo ./setup.sh
```

## What Gets Installed

1. **System packages**: 
   - Core: curl, wget, git, htop, vim, nano, jq
   - Tools: mc, lsof, tmux, screen
   - Python: python3, pip, venv, virtualenv
   - Modern CLI: neovim, zsh, fzf, bat, ripgrep, eza
2. **Security**: UFW (ports 22, 80, 443), fail2ban, SSH key-only auth
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
export DISCORD_WEBHOOK="https://discord.com/api/webhooks/..."
```

If not set, monitoring will be skipped.

## Post-Install

After successful setup:

1. **Logout and login again** (new shell: zsh with oh-my-zsh)
2. Configure Age key: `~/.config/sops/age/keys.txt`
3. Test Discord alerts: `/opt/monitoring/test-notification.sh`
4. Test new aliases: `gst` (git status), `ll` (eza ls), `d ps` (docker ps)
5. Reboot recommended: `sudo reboot`

## Files

```
vps-bootstrap/
├── setup.sh              # Main orchestrator
├── scripts/
│   ├── 01-system.sh      # System updates
│   ├── 02-security.sh    # Firewall, fail2ban, SSH
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
