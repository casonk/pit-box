# Security model

## Defaults

This repository assumes:

- no direct public exposure of SSH
- no direct public exposure of RDP
- SSH key-only authentication
- no root SSH login
- WireGuard is the first and only public ingress
- admin web UIs are reachable only over LAN/VPN

## Threat reduction goals

- reduce attack surface on WAN
- avoid repeated credential prompts on public services
- separate tunnel authentication from shell authentication
- keep administration private

## Firewall intent

Allow:

- inbound UDP on the WireGuard listen port
- inbound SSH only from the VPN interface/subnet
- inbound RDP only from the VPN interface/subnet when remote desktop is enabled

Optionally allow forwarding:

- from WireGuard subnet to LAN subnet
- from LAN back to WireGuard subnet
- masquerade for full-tunnel internet egress

## SSH stance

Recommended configuration:

- `PubkeyAuthentication yes`
- `PasswordAuthentication no`
- `KbdInteractiveAuthentication no`
- `PermitRootLogin no`

## Secrets handling

Private keys and local settings are generated into untracked directories:

- `secrets/`
- `settings.env`
- `config/auto-pass.ini`

Do not commit them.

Guacamole remote desktop credentials should be stored in auto-pass through the
`REMOTE_DESKTOP_WEB_PASSWORD_KEEPASS_ENTRY` setting. `REMOTE_DESKTOP_WEB_PASSWORD`
is an ignored local fallback only and should not be used for normal operation.

## Web UI guidance

If you later deploy an admin web UI, it should be:

- reachable only over LAN/VPN
- protected by local authentication
- omitted entirely if SSH is sufficient

## Remote desktop guidance

RDP/xrdp is an optional direct VPN-only service. Keep TCP 3389 off the public
router, bind xrdp to the WireGuard tunnel address with
`port=tcp://IP:PORT`, and apply the repo firewall scripts after enabling
`REMOTE_DESKTOP_ENABLED=true`.
