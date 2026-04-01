# Architecture

## Primary recommendation

The server acts as the WireGuard endpoint. The iPhone is a remote peer.

```text
iPhone --WireGuard--> home router (UDP 51820) --> Linux server
                                               ├── SSH
                                               ├── SMB
                                               └── optional internal-only web UIs
```

## Why this design

- Only one service needs to be reachable from the internet
- SSH remains private
- Other internal services are reachable only after VPN authentication
- The iPhone can either reach:
  - just the server
  - the entire LAN
  - the full internet via home

## Routing modes

### Server-only
Client routes only to the WireGuard subnet.

### LAN
Client routes to the WireGuard subnet and the home LAN subnet.

### Full-tunnel
Client sends all traffic through the home server. This requires NAT/masquerading on the server.

## Trust boundaries

### Public internet
Only WireGuard UDP listen port should be exposed.

### VPN boundary
SSH, SMB, and other internal services are reachable only after the VPN is established.

### Local host
System services remain bound to LAN or all interfaces as configured locally, but exposure is controlled by the firewall and network path.

## Components

- WireGuard
- SSH server
- Linux firewall
- Optional SMB server
- Optional internal web UI

## Manual external dependencies

- Router port-forward
- Dynamic DNS provider or static public IP
- iPhone WireGuard app
