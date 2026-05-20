# harden

One-command Linux server hardening. Uses [Lynis](https://cisofy.com/lynis/) for auditing, then applies common security fixes automatically.

```bash
curl -fsSL https://raw.githubusercontent.com/kaka-ruto/harden/main/bin/harden | bash -s -- root@your-server
```

## Usage

```bash
# Full hardening (Lynis audit + fixes)
bin/harden root@46.225.145.255

# Allow your IP on DB ports (PostgreSQL, PgBouncer)
bin/harden root@46.225.145.255 --allow-db-from 129.222.147.133

# Audit only — see what needs fixing without changing anything
bin/harden root@46.225.145.255 --check
```

## What it does

### Fixes

| Area | What it does |
|---|---|
| **UFW firewall** | Drops all incoming traffic except SSH, HTTP, HTTPS, and optional DB ports from your IP |
| **SSH** | Root login key-only (`prohibit-password`), password auth disabled, keyboard-interactive disabled |
| **fail2ban** | Installs and configures sshd jail — blocks IPs after 5 failed attempts |
| **Docker daemon** | Disables inter-container communication, sets log limits (10MB rotated) |
| **telnet** | Removes `inetutils-telnet` if present |
| **unattended-upgrades** | Ensures automatic security updates are installed |

### Audit

All checks are run before and after fixes, using Lynis (auto-installed if missing) with a before/after score comparison.

### Idempotent

Safe to re-run. No changes are made if the desired state is already active. Docker is only restarted if daemon.json actually changes.

## Installation

The script is standalone — no dependencies beyond `bash`, `ssh`, and a Debian/Ubuntu server.

```bash
# Clone
git clone git@github.com:kaka-ruto/harden.git
cd harden

# Or download just the script
curl -fsSL https://raw.githubusercontent.com/kaka-ruto/harden/main/bin/harden > harden
chmod +x harden
```

## Testing

```bash
# Requires Docker (spins up a test container)
./tests/test_harden.sh
```

## License

MIT
