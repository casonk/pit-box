# Security model

## Defaults

This repository assumes:

- no direct public exposure of SSH
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

Do not commit them.

## Web UI guidance

If you later deploy an admin web UI, it should be:

- reachable only over LAN/VPN
- protected by local authentication
- omitted entirely if SSH is sufficient
