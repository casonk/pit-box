# Contributor Architecture Blueprint — pit-box

## Purpose

pit-box is a WireGuard + SSH hardened remote-access setup scaffold. It
provides a reproducible, settings-driven pipeline for generating WireGuard
server and client configs, an SSH hardening snippet, firewall rules, and a
distributable client bundle. It also owns optional VPN-only admin surfaces such
as ttyd and xrdp — without ever committing secret material into version
control.

The sole public internet-facing service is WireGuard. SSH is only reachable
over the VPN tunnel. RDP and admin web UIs are never exposed publicly by
default.

---

## Routing Modes

The `ROUTING_MODE` variable in `settings.env` controls how IP forwarding and
`AllowedIPs` are configured at render time:

| Mode          | Description                                                  |
|---------------|--------------------------------------------------------------|
| `server-only` | Clients reach the server host only; no LAN or internet routing |
| `lan`         | Clients can reach the server's LAN subnet via the tunnel     |
| `full-tunnel` | All client traffic is routed through the server (default-route override) |

Routing mode is opt-in. `server-only` is the minimal-privilege default.

---

## Pipeline Overview

### 1. Config Rendering

```
settings.env
    └─► scripts/render_configs.sh
            ├─► build/server/wg0.conf          (WireGuard server config)
            ├─► build/client/<peer>.conf        (WireGuard client config)
            └─► build/ssh/sshd_config.snippet   (SSH hardening overlay)
```

`render_configs.sh` reads `settings.env`, substitutes variables into the
templates under `configs/`, and writes rendered output to `build/`. The
`build/` directory is gitignored — it contains environment-specific data.

### 2. Installation

```
scripts/install.sh              (distro-agnostic entry point)
scripts/install_ubuntu.sh       (Ubuntu/Debian-specific)
scripts/install_fedora.sh       (Fedora/RHEL-specific)
scripts/install_remote_desktop.sh (optional xrdp/RDP over WireGuard)
```

Install scripts ensure WireGuard, OpenSSH, and required tools are present. The
remote-desktop installer is opt-in and configures xrdp only when
`REMOTE_DESKTOP_ENABLED=true`.

### 3. Key Generation

```
scripts/generate_keys.sh
    └─► secrets/<peer>.privkey, secrets/<peer>.pubkey, secrets/psk
```

Keys land in `secrets/` which is gitignored. The `secrets/README.md`
documents the expected layout.

### 4. System Hardening

```
scripts/harden_ssh.sh
    └─► applies build/ssh/sshd_config.snippet to /etc/ssh/sshd_config.d/
```

SSH hardening enforces public-key-only auth, disables root login, and
restricts listening to the WireGuard interface.

### 5. Firewall Configuration

```
scripts/configure_ufw.sh        (Ubuntu/Debian — UFW)
scripts/configure_firewalld.sh  (Fedora/RHEL — firewalld)
scripts/enable_ip_forwarding.sh (enables kernel IP forwarding for lan/full-tunnel modes)
```

Firewall scripts open only the WireGuard UDP port on the public interface,
allow private services on the WireGuard interface, and allow forwarded traffic
on the WireGuard interface. All other inbound is denied.

### 6. Validation

```
scripts/validate.sh
    └─► checks build/ outputs for correctness, completeness, and secret-free content
```

Run `validate.sh` after every render and before packaging.

### 7. Client Packaging

```
scripts/package_client.sh
    └─► bundles build/client/ into dist/pit-box-client.zip
```

`dist/` is gitignored. The zip is for offline distribution to VPN peers only.

---

## Directory Layout

```
pit-box/
├── configs/                # Example/template WireGuard and SSH configs
│   ├── wireguard/
│   │   ├── wg0.conf.example
│   │   └── client.conf.example
│   ├── remote-desktop/
│   │   └── xrdp.ini.example
│   └── ssh/
│       └── sshd_config.snippet.example
├── scripts/                # All shell scripts
├── docs/                   # Architecture, security model, troubleshooting
├── secrets/                # Gitignored — runtime keys and PSKs only
├── build/                  # Gitignored — rendered output
├── dist/                   # Gitignored — packaged client bundles
├── settings.env.example    # Template — copy to settings.env, never commit settings.env
└── AGENTS.md               # Agent operating rules for this repo
```

---

## Security Boundaries

| Boundary         | Rule                                                    |
|------------------|---------------------------------------------------------|
| `secrets/`       | Never committed except `.gitkeep` and `README.md`       |
| `build/`         | Never committed — contains rendered env-specific configs |
| `dist/`          | Never committed — contains packaged client bundles       |
| `settings.env`   | Never committed — contains real IPs, ports, key paths    |
| Example configs  | Committed — must use placeholder values only             |

---

## Adding a New Routing Mode or Script

1. Open an issue describing the change.
2. Update `settings.env.example` with any new variables.
3. Update `configs/` templates if new substitution variables are needed.
4. Update `scripts/render_configs.sh` to handle the new mode/variable.
5. Update `scripts/validate.sh` to check the new outputs.
6. Update `docs/architecture.md` and this blueprint.
7. Run `pre-commit run --all-files` and `scripts/validate.sh` before opening a PR.
