# pit-box

Secure iPhone ↔ Linux server access via WireGuard

A starter repository for reaching a home Linux server from an iPhone **from anywhere** using:

- **WireGuard** as the secure private entry point
- **SSH** for administration
- **SMB** or other internal services over the VPN
- Optional **web UIs** only **behind** the VPN

This repo packages the design from the conversation into a reusable setup scaffold.

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
│   └── ssh
│       └── sshd_config.snippet
├── docs
│   ├── architecture.md
│   ├── security-model.md
│   └── troubleshooting.md
└── scripts
    ├── install.sh
    ├── install_fedora.sh
    ├── install_ubuntu.sh
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

### 10. Validate

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
