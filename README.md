# pit-box

Secure iPhone ↔ Linux server access via WireGuard

A starter repository for reaching a home Linux server from an iPhone **from anywhere** using:

- **WireGuard** as the secure private entry point
- **SSH** for administration
- **SMB** or other internal services over the VPN
- Optional **web UIs** only **behind** the VPN

This repo packages the design from the conversation into a reusable setup scaffold.

Consent reference: [`../../doc-repos/my-consent/remote-access-and-private-files.md`](../../doc-repos/my-consent/remote-access-and-private-files.md) documents the explicit consent covering personal remote-access, private-file, and device-profile processing handled by this repo.

## Goals

- Do **not** expose SSH or admin web UIs directly to the public internet
- Use **WireGuard** as the only public-facing remote access layer
- Reach the server by its **WireGuard IP**
- Optionally route access to your **entire home LAN**
- Keep installation mostly scriptable, with the unavoidable manual router/DDNS steps documented

## Repository layout

```text
.
├── AGENTS.md
├── README.md
├── settings.env.example
├── configs
│   ├── client
│   │   └── iphone.conf.example
│   ├── server
│   │   └── wg0.conf.example
│   ├── ssh
│   │   └── sshd_config.snippet
│   └── webterm
│       ├── dnsmasq-vpn.conf.example
│       └── ttyd.service.example
├── docs
│   ├── architecture.md
│   ├── security-model.md
│   └── troubleshooting.md
└── scripts
    ├── install.sh
    ├── install_fedora.sh
    ├── install_ubuntu.sh
    ├── install_webterm.sh
    ├── rebuild_webservices.sh
    ├── generate_keys.sh
    ├── render_configs.sh
    ├── enable_ip_forwarding.sh
    ├── configure_ufw.sh
    ├── configure_firewalld.sh
    ├── harden_ssh.sh
    ├── validate.sh
    └── package_client.sh
```

## Architecture

```text
iPhone
  │
  │ WireGuard
  ▼
[ Public Internet ]
  │
  ▼
Home Router (UDP 51820 forwarded)
  │
  ▼
Linux Server (WireGuard endpoint, SSH server)
  │
  ├── SSH to 10.8.0.1
  ├── Web Terminal (ttyd) at http://10.8.0.1:7681 (VPN-only)
  ├── SMB to 192.168.1.x or 10.8.0.1
  └── Optional Cockpit / other web UIs only over VPN
```

## Suggested defaults

These examples assume:

- Home LAN: `192.168.1.0/24`
- Linux server LAN IP: `192.168.1.10`
- WireGuard subnet: `10.8.0.0/24`
- Server WireGuard IP: `10.8.0.1`
- iPhone WireGuard IP: `10.8.0.2`
- WireGuard listen port: `51820/udp`

## What you need to do manually

Some steps cannot be safely automated from inside the server:

1. **Router port-forward**
   - Forward **UDP 51820** from your router to the Linux server.
2. **Dynamic DNS**
   - Point a hostname to your home public IP if your ISP changes it periodically.
3. **iPhone app**
   - Install the WireGuard app on the iPhone and import the generated client config.
4. **Optional router / LAN policies**
   - Allow the Linux server to reach other LAN devices if you want LAN access through the tunnel.

## Quick start

### 1. Copy the example settings

```bash
cp settings.env.example settings.env
$EDITOR settings.env
```

Fill in the variables to match your environment.

### 2. Install dependencies

Ubuntu/Debian:

```bash
sudo ./scripts/install_ubuntu.sh
```

Fedora:

```bash
sudo ./scripts/install_fedora.sh
```

Portable wrapper:

```bash
sudo ./scripts/install.sh
```

### 3. Generate keys

```bash
./scripts/generate_keys.sh
```

This creates keys under `./secrets/`.

### 4. Render configs

```bash
./scripts/render_configs.sh
```

This creates:

- `build/server/wg0.conf`
- `build/client/iphone.conf`
- `build/ssh/sshd_config.snippet`
- `build/webterm/ttyd.service` (only when `WEBTERM_ENABLED=true`)

### 5. Install the server config

```bash
sudo cp build/server/wg0.conf /etc/wireguard/wg0.conf
sudo chmod 600 /etc/wireguard/wg0.conf
sudo systemctl enable --now wg-quick@wg0
```

### 6. Enable forwarding if you want LAN access

```bash
sudo ./scripts/enable_ip_forwarding.sh
```

### 7. Configure the firewall

For Ubuntu with UFW:

```bash
sudo ./scripts/configure_ufw.sh
```

For Fedora with firewalld:

```bash
sudo ./scripts/configure_firewalld.sh
```

### 8. Harden SSH

```bash
sudo ./scripts/harden_ssh.sh
```

This adds a drop-in snippet to restrict SSH to key-based auth and disables root login.

### 9. Package the iPhone config for transfer

```bash
./scripts/package_client.sh
```

This creates `dist/pit-box-client.zip` containing the client config and a QR-friendly text copy.

### 10. (Optional) Install the web terminal

Enable in `settings.env` (`WEBTERM_ENABLED=true`, set `WEBTERM_PORT` and `WEBTERM_HOSTNAME`), then
re-render and install:

```bash
./scripts/render_configs.sh
sudo ./scripts/configure_ufw.sh        # or configure_firewalld.sh
sudo ./scripts/install_webterm.sh
./scripts/package_client.sh            # re-package — client DNS was updated
```

This installs **ttyd** (web terminal), the loopback-only **pit-box API** used by the home page,
and **dnsmasq** (VPN-scoped DNS resolver), all bound to the WireGuard path only. Re-import the
client config on your iPhone — the `DNS` field is updated to point at the server so
`WEBTERM_HOSTNAME` resolves over the tunnel. The install step also deploys the home page and
regenerates the terminal page so mobile browsers get tmux controls, arrows, `Tab`, `Esc`,
`Ctrl+C`, font scaling, and buffer scroll helpers.

Point a browser (over VPN) at `https://webterm.home/` — you will be prompted to log in with
your local Unix credentials.

### 11. Validate

```bash
./scripts/validate.sh
```

## Access models

### Model A: Server only

Use this if you only need the home Linux server.

- iPhone peer `AllowedIPs = 10.8.0.0/24`
- SSH to `10.8.0.1`

### Model B: Whole LAN

Use this if you also want access to NAS devices, printers, or router-adjacent services.

- iPhone peer `AllowedIPs = 10.8.0.0/24, 192.168.1.0/24`
- Enable IP forwarding
- Allow forwarding between `wg0` and the LAN interface

### Model C: Full tunnel

Use this if you want all iPhone traffic to exit through home.

- iPhone peer `AllowedIPs = 0.0.0.0/0, ::/0`
- Also configure NAT/masquerading on the server

This repo defaults to **Model B** because it is the most practical balance for home use.

## Notes on SSH

The expectation here is:

- You connect to the server’s **WireGuard IP**
- SSH is **not** exposed on the public WAN
- Password auth is disabled
- Public key auth is enabled
- Root login is disabled
- Session keepalive is enabled (`ClientAliveInterval 30`, `ClientAliveCountMax 6`) — the server
  polls idle clients every 30 seconds and drops the connection after 3 minutes of no response

## Notes on the web terminal

- **ttyd** serves an xterm.js terminal behind Caddy at `https://WEBTERM_HOSTNAME/`
- `/` shows the home page with tmux windows and currently connected browser terminals
- `/term` opens the terminal page with mobile helper buttons, font scaling, and buffer scroll
  controls
- The service binds exclusively to the WireGuard tunnel IP — never to the public interface
- It invokes `/bin/login`, so you authenticate with your local Unix username and password
- WebSocket keepalives (`--ping-interval 30`) prevent the browser session from going idle
- Only accessible from devices connected to the WireGuard VPN
- The generated terminal page includes mobile helper keys for tmux window control, arrows, `Tab`,
  `Esc`, `Ctrl+C`, `Ctrl+D`, `Ctrl+L`, plus direct buffer scroll buttons and persistent font scaling
- A reconnect inherits the last tmux window selected by the disconnected browser terminal instead of
  always falling back to window `0`
- The home page polls the loopback pit-box API so it can show both tmux windows and live browser
  terminals, not just the shared tmux session state
- **dnsmasq** runs on the server's WireGuard tunnel IP, resolving `WEBTERM_HOSTNAME` locally and
  forwarding all other queries to `LAN_DNS_SERVER` — it uses `bind-interfaces` so it does not
  conflict with `systemd-resolved` or other host resolvers
- When `WEBTERM_ENABLED=true`, the rendered client config sets `DNS = WG_SERVER_TUNNEL_IP` so the
  hostname resolves over the tunnel; re-import the iPhone config after enabling
- Opt-in: set `WEBTERM_ENABLED=true`, `WEBTERM_PORT`, and `WEBTERM_HOSTNAME` in `settings.env`
- If the browser shows stale web terminal UI, run
  `sudo ./scripts/rebuild_webservices.sh ttyd` and then hard-refresh the browser. Rebuilding
  `ttyd` also refreshes the coupled home-page API.

## Notes on SMB and web UIs

- SMB can be used from the iPhone **over the VPN**
- Admin web UIs should remain **LAN/VPN-only**
- Do not publish tools like Cockpit directly to the public internet

## Recommended workflow

- WireGuard up on the iPhone
- SSH into `10.8.0.1`
- Optionally use Files → Connect to Server for SMB shares over VPN
- Keep all admin surfaces private

## Files generated by scripts

The scripts intentionally separate sources from outputs:

- `settings.env`: your local configuration
- `secrets/`: generated private/public keys
- `build/`: rendered server/client configs
- `dist/`: packaged client bundle

Add `settings.env` and `secrets/` to your private backup workflow. They are ignored in the provided `.gitignore`.

## Safety

This repo is a scaffold. Review all generated configs before applying them to a live machine.
