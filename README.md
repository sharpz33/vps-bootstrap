# VPS Bootstrap

Automated VPS setup for Ubuntu 24.04 LTS with security hardening, Docker, and monitoring.

## Supported Systems

- **Ubuntu 24.04 LTS** (primary and only supported distro)

## Features

- **Preflight checks**: System requirements validation (RAM, disk space, internet connectivity)
- **Advanced logging**: Timestamped logs with automatic error handling and summary
- System updates and essential packages
- **Development tools**: mc, tmux, neovim, Python (pip, venv)
- **Modern CLI tools**: eza, fzf, bat, ripgrep
- **Shell**: zsh with oh-my-zsh (agnoster theme) set as default
- **Shell enhancements**: git aliases (oh-my-zsh style), Docker shortcuts, system monitoring
- **Terminal compatibility**: Auto-fixes for Ghostty and modern terminals (TERM, locale, key bindings)
- Security hardening (UFW firewall, fail2ban, SSH hardening, sudo password tries)
- Docker + Docker Compose installation with DNS resolver fix
- SOPS + Age for secrets management
- Monitoring with Discord notifications (disk alerts, uptime)
- **Fully idempotent**: Safe to re-run, auto-detects existing configuration

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
git clone https://github.com/sharpz33/vps-bootstrap.git
cd vps-bootstrap

# Make scripts executable
chmod +x setup.sh scripts/*.sh

# Run setup (requires sudo)
# You'll be prompted for:
# - Username for new sudo user (if no sudo user exists)
# - Discord webhook for monitoring alerts (optional)
sudo ./setup.sh

# Or set via environment variables to skip prompts
export VPS_USERNAME="yourusername"
export DISCORD_WEBHOOK="https://discord.com/api/webhooks/YOUR_WEBHOOK"
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
   - Sudo password tries increased to 10 (from default 3)
3. **Docker**: Latest Docker Engine + Docker Compose v2
4. **SOPS**: Secrets encryption with Age
5. **Monitoring**:
   - Disk space alerts via Discord webhook
   - Hourly health checks
   - Configuration stored in `/opt/monitoring/config`
6. **Shell**:
   - zsh with oh-my-zsh (agnoster theme) set as default
   - Terminal compatibility fixes (TERM=xterm-256color for Ghostty and modern terminals)
   - True color support (COLORTERM=truecolor)
   - Locale settings (UTF-8)
   - Fixed key bindings (backspace, delete)
   - Git aliases (oh-my-zsh style): g, ga, gc, gco, gst, glog, etc.
   - Docker shortcuts: d, dc, dps, dlog
   - System monitoring aliases

## Configuration

The setup script will prompt you interactively for configuration if not provided via environment variables.

### Interactive prompts:
- **Username**: Prompted only if no sudo user exists (auto-detected on re-runs)
- **Discord webhook**: Prompted during monitoring setup (can skip)

### Skip prompts with environment variables:

```bash
# Username for new sudo user (auto-detected if already exists)
export VPS_USERNAME="yourusername"

# Discord webhook for monitoring alerts (will prompt if not set)
export DISCORD_WEBHOOK="https://discord.com/api/webhooks/..."
```

### Configure Discord webhook later:

```bash
# Edit monitoring config
sudo nano /opt/monitoring/config

# Add:
DISCORD_WEBHOOK="https://discord.com/api/webhooks/YOUR_WEBHOOK"

# Test
sudo /opt/monitoring/test-notification.sh
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
6. Review installation logs: `tail -100 /var/log/vps-bootstrap.log`
7. Reboot recommended: `sudo reboot`

**IMPORTANT:** Root SSH login is now disabled. Always use your sudo user for SSH access.

### Troubleshooting

**Check installation logs:**
```bash
# View full log
less /var/log/vps-bootstrap.log

# View last 50 lines
tail -50 /var/log/vps-bootstrap.log

# Search for errors
grep -i error /var/log/vps-bootstrap.log
```

## Files

```
vps-bootstrap/
├── setup.sh              # Main orchestrator
├── lib/
│   └── helpers.sh        # Logging, error handling, utilities
├── scripts/
│   ├── 00-preflight.sh   # System requirements validation
│   ├── 01-user.sh        # User creation with sudo
│   ├── 02-system.sh      # System updates and packages
│   ├── 03-security.sh    # Firewall, fail2ban, SSH hardening
│   ├── 04-docker.sh      # Docker installation
│   ├── 05-monitoring.sh  # Monitoring setup
│   └── 06-sops.sh        # SOPS + Age
└── config/
    ├── ufw.rules         # Firewall rules
    └── fail2ban.conf     # Fail2ban config
```

## Idempotency

**This setup is fully idempotent** - safe to re-run multiple times without breaking your system.

### How it works:

- **User creation (`01-user.sh`)**:
  - Automatically detects existing sudo users
  - Only prompts for username if no sudo user exists
  - Skips creation if user already configured
  - Ensures SSH keys and sudo access are properly set up

- **System packages (`02-system.sh`)**:
  - Checks if packages are installed before attempting installation
  - Skips oh-my-zsh installation if already present
  - Updates configuration files only if needed

- **Security (`03-security.sh`)**:
  - Verifies existing firewall rules before applying
  - Checks fail2ban status before configuration
  - Validates SSH config before restart

- **Docker (`04-docker.sh`)**:
  - Detects existing Docker installation
  - Skips if already installed and configured
  - Updates configuration if needed

### Re-running the setup:

```bash
# First run - prompts for username
sudo ./setup.sh

# Second run - auto-detects existing user, no prompt!
sudo ./setup.sh

# Or specify username explicitly
VPS_USERNAME=myuser sudo ./setup.sh
```

**Output on subsequent runs:**
```
[INFO] Found existing sudo user: myuser
[INFO] Skipping user creation (system is already configured)
[INFO] oh-my-zsh already installed
[INFO] Docker already installed: Docker version 24.0.x
...
```

## License

MIT
