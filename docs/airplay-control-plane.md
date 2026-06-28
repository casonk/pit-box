# AirPlay Control Plane

The pit-box loopback API can start, stop, and inspect an Android AirPlay
receiver through ADB. Caddy continues to provide the only browser ingress:
WireGuard DNS plus mandatory client-certificate authentication.

## Security boundaries

- Never expose TCP 5555 through Caddy or to the public internet.
- Permit ADB only from the control-plane host or a dedicated home-side agent.
- Do not treat the receiver PIN as the network access boundary.
- Put the TV on an isolated VLAN/SSID. Allow the WireGuard subnet to reach the
  TV's AirPlay ports, while denying guest and ordinary LAN subnets.
- Reflect mDNS only between the WireGuard interface and the isolated TV
  interface. Do not reflect guest-network multicast.

Guest Wi-Fi isolation is an acceptable interim boundary if guests never receive
primary-LAN credentials. It is not strict tunnel-only enforcement: a device on
the same primary LAN can contact the TV without traversing the VPN gateway.

## Controller configuration

Set these local-only values in `settings.env`:

```dotenv
AIRPLAY_CONTROL_ENABLED=true
AIRPLAY_ADB_TARGET=<tv-or-home-agent-address>:5555
```

The tracked example deliberately uses IANA TEST-NET-1. Repository validation
rejects a private or deployment-like address in `settings.env.example`; real
addresses belong only in the gitignored `settings.env`.

Then render and rebuild the existing API:

```bash
./scripts/render_configs.sh
sudo ./scripts/rebuild_webservices.sh api
```

The API runs `adb` with a fixed receiver package and fixed command shapes.
Requests can select only `start` or `stop`; they cannot supply shell commands.

## Required network completion

The US server must first have a site-to-site route to the TV-side network. If it
does not, deploy a small home-side agent that connects outbound through the
tunnel instead of opening ADB remotely.

Casting clients additionally require:

1. a route for the TV subnet in their WireGuard `AllowedIPs`;
2. forwarding/firewall rules from the WireGuard subnet to the TV;
3. scoped mDNS reflection for `_airplay._tcp` and `_raop._tcp`;
4. firewall denial from guest/ordinary LAN subnets to the isolated TV network.

Media should take the shortest tunnel path to the home network. The web control
plane may live in the US, but unnecessarily hairpinning video through it adds
latency and is not an access-control requirement.
