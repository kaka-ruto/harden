# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-05-20

### Added

- One-command server hardening via `harden <user@host>`
- Lynis auto-install with before/after audit comparison
- UFW firewall — restrict to SSH, HTTP, HTTPS, optional DB ports
- SSH hardening — root key-only, passwords disabled, keyboard-interactive disabled
- fail2ban — brute force protection with sshd jail
- Docker daemon hardening — inter-container communication disabled, log limits
- telnet removal, unattended-upgrades ensured
- `--check` mode — audit only, no changes
- `--allow-db-from` — restrict DB ports to your IP
- `--local` mode — run on the machine directly
- `help`, `version`, `update` subcommands
- Idempotent — safe to re-run without side effects
- Docker-based integration tests (12 tests)
- CI workflow (PR + push to master)
- CD workflow (tag push creates GitHub release)
