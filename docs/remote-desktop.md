# Remote Desktop

`pit-box` supports two opt-in phone-to-desktop paths over the existing
WireGuard tunnel:

- native RDP through an RDP app
- Safari access through an Apache Guacamole browser gateway

Neither path is a public internet endpoint.

## Ownership

- `pit-box` owns the xrdp install/configuration and firewall intent.
- `pit-box` also owns the Guacamole gateway when Safari access is enabled.
- `short-circuit` or the existing pit-box WireGuard config owns the tunnel.
- `wiring-harness` owns the optional private hostname and DNS inventory.
- `snowbridge` can stage mobile profiles or notes, but does not own the
  remote-desktop service.

## Safety Model

- Forward only the WireGuard UDP port from the router.
- Do not port-forward TCP 3389 from the public internet.
- Bind xrdp to the WireGuard server address with xrdp's `port=tcp://IP:PORT`
  syntax.
- Bind the Guacamole web container to loopback and expose it only through
  Caddy over VPN/mTLS.
- Apply firewall rules so TCP 3389 is accepted only on the WireGuard interface.
- Use a local desktop account that is appropriate for interactive login.

## Settings

Copy `settings.env.example` to `settings.env` and enable:

```bash
REMOTE_DESKTOP_ENABLED=true
REMOTE_DESKTOP_PORT=3389
REMOTE_DESKTOP_BIND_ADDRESS=10.8.0.1
REMOTE_DESKTOP_HOSTNAME=
REMOTE_DESKTOP_WEB_ENABLED=true
REMOTE_DESKTOP_WEB_HOSTNAME=
REMOTE_DESKTOP_WEB_PORT=8090
REMOTE_DESKTOP_WEB_USER=iphone
REMOTE_DESKTOP_WEB_PASSWORD=
REMOTE_DESKTOP_WEB_PASSWORD_KEEPASS_ENTRY=pit-box/remote-desktop/guacamole
REMOTE_DESKTOP_WEB_PASSWORD_KEEPASS_PROFILE=infra
REMOTE_DESKTOP_WEB_AUTO_PASS_ENV_FILE=
REMOTE_DESKTOP_GUACAMOLE_UID=1001
REMOTE_DESKTOP_GUACAMOLE_GID=1001
```

Leave `REMOTE_DESKTOP_HOSTNAME` blank to use the `pit-box-rdp` entry from the
sibling `wiring-harness` registry when present, or connect directly to
`WG_SERVER_TUNNEL_IP`.

Leave `REMOTE_DESKTOP_WEB_HOSTNAME` blank to use the `pit-box-remote-desktop`
entry from the sibling `wiring-harness` registry.

Prefer `REMOTE_DESKTOP_WEB_PASSWORD_KEEPASS_ENTRY` so the Guacamole login is
managed by the sibling `auto-pass` repo. `REMOTE_DESKTOP_WEB_PASSWORD` remains
only as an ignored local fallback.

## Optional Wiring Harness Entry

For private DNS and inventory, add this to
`../wiring-harness/services.local.toml`:

```toml
[[services]]
name        = "pit-box-rdp"
description = "RDP remote desktop"
owner_repo  = "./util-repos/pit-box"
hostname    = "rdp.home.internal"
access_mode = "vpn-only-direct"
ingress     = "direct"
port        = 3389

[[services]]
name        = "pit-box-remote-desktop"
description = "Safari remote desktop"
owner_repo  = "./util-repos/pit-box"
hostname    = "desktop.home.internal"
access_mode = "shared-mtls"
ingress     = "repo-caddy"
port        = 8090
```

Then refresh wiring-harness DNS material:

```bash
cd ../wiring-harness
WH_WG_IP=10.8.0.1 bash scripts/setup-mtls.sh
python3 scripts/render_private_site_inventory.py
```

The RDP entry is `ingress = "direct"`, so it is published to the private DNS
inventory but is not reverse-proxied through Caddy. The Safari entry is
`ingress = "repo-caddy"` because `pit-box` renders its own Caddy drop-in while
`wiring-harness` still owns hostname inventory, DNS, and shared mTLS material.

If the phone WireGuard profile was rendered before the hostname existed, rerun
`./scripts/render_configs.sh` and `./scripts/package_client.sh` from `pit-box`,
then re-import the client profile. The rendered client uses the WireGuard
server as DNS whenever a private hostname is enabled.

## Install

From the `pit-box` repo:

```bash
./scripts/render_configs.sh
python3 scripts/export_remote_desktop_password_to_keepass.py --generate
./scripts/render_remote_desktop_gateway.sh
sudo ./scripts/install_remote_desktop.sh
sudo ./scripts/install_remote_desktop_gateway.sh
sudo ./scripts/configure_firewalld.sh   # Fedora/RHEL
# or: sudo ./scripts/configure_ufw.sh   # Ubuntu/Debian
./scripts/package_client.sh
```

The installer installs `xrdp` plus `xorgxrdp`, updates `/etc/xrdp/xrdp.ini`
with `port=tcp://REMOTE_DESKTOP_BIND_ADDRESS:REMOTE_DESKTOP_PORT`, adds a
systemd drop-in ordering xrdp after `wg-quick@WG_INTERFACE.service`, and
restarts xrdp.

The Safari gateway installer starts `guacamole/guacd` plus
`guacamole/guacamole` with Podman Compose, binds the web app to
`127.0.0.1:REMOTE_DESKTOP_WEB_PORT`, and installs a Caddy mTLS reverse proxy at
`https://REMOTE_DESKTOP_WEB_HOSTNAME/`. On SELinux hosts, the Guacamole config
volume is mounted with a private container label. The config directory is owned
by the Guacamole container UID/GID, which defaults to `1001:1001` for the
official image.

If a password already exists in ignored `settings.env`, export it into
auto-pass once:

```bash
python3 scripts/export_remote_desktop_password_to_keepass.py --allow-interactive
```

For a fresh password generated directly into auto-pass:

```bash
python3 scripts/export_remote_desktop_password_to_keepass.py --generate --allow-interactive
```

## Connect From iPhone Safari

1. Connect the phone to WireGuard.
2. Open Safari.
3. Browse to `https://desktop.home.internal/`.
4. Log in to Guacamole with `REMOTE_DESKTOP_WEB_USER` and
   the password stored at `REMOTE_DESKTOP_WEB_PASSWORD_KEEPASS_ENTRY`.
5. Open the `Pit Box Desktop` connection.
6. Log in to the xrdp desktop session with a local desktop account.

If Safari cannot resolve the hostname, check wiring-harness DNS plus the
`DNS = WG_SERVER_TUNNEL_IP` line in the phone WireGuard profile. If Safari
shows a certificate or client-certificate error, refresh the wiring-harness
mTLS mobileconfig for the iPhone and reinstall it.
