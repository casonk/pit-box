# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

## [0.1.0] - 2026-01-01

### Added

- Initial WireGuard + SSH hardened remote-access setup scaffold.
- `settings.env`-driven config rendering flow via `scripts/render_configs.sh`.
- Server/client WireGuard config templates in `configs/`.
- SSH hardening snippet and `sshd_config` template.
- Install scripts for Ubuntu and Fedora.
- Firewall configuration scripts for UFW and firewalld.
- `scripts/validate.sh` for end-to-end output validation.
- `scripts/package_client.sh` for bundling client distribution artifacts.
- Key generation helper in `scripts/`.
- `secrets/` directory (gitignored) with `.gitkeep` and usage `README.md`.
- Architecture, security-model, and troubleshooting docs in `docs/`.
