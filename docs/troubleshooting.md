# Troubleshooting

## Tunnel does not connect

Check:

1. router port-forward for UDP 51820
2. DDNS name resolves to the current public IP
3. server firewall allows UDP 51820
4. `sudo wg show`
5. server clock is sane

## Handshake appears but LAN devices are unreachable

Check:

1. IP forwarding is enabled
2. forwarding rules exist between `wg0` and the LAN interface
3. the Linux server can itself reach the LAN devices
4. target LAN devices are not blocking the server

## SSH works locally but not over VPN

Check:

1. the iPhone can ping or otherwise reach `10.8.0.1`
2. SSH is listening on the server
3. firewall rules allow SSH from `wg0`
4. you are connecting to the WireGuard IP, not the public IP

## Full tunnel breaks normal browsing

Check:

1. NAT/masquerading is enabled on the server
2. default route mode is intended
3. DNS is set to a reachable resolver from inside the tunnel

## Client import problems

Check:

1. the generated config has valid keys
2. endpoint hostname and port are correct
3. the `AllowedIPs` line matches the desired routing mode
4. line endings were not mangled during transfer

## Web terminal loads but helper keys are missing

Check:

1. `systemctl cat ttyd` includes `--index /etc/pit-box/webterm/index.html`
2. rerun `sudo ./scripts/rebuild_webservices.sh ttyd` to redeploy the terminal page and refresh the coupled home-page API
3. hard-refresh the browser after the ttyd restart so the old page is not cached

## Home page does not show live terminals

Check:

1. `systemctl status pit-box-api` is healthy
2. `sudo ./scripts/rebuild_webservices.sh ttyd` redeploys the home page, terminal page, and API together
3. opening a second browser tab should increase the Live terminals count within a few seconds

## Reconnect jumps back to window 0

Check:

1. `/etc/pit-box/ttyd_session.sh` includes both `display-message` and `select-window`
2. `sudo ./scripts/rebuild_webservices.sh ttyd` redeploys the updated ttyd session wrapper
3. disconnect and reconnect after the ttyd restart so the next browser session inherits the last tmux window
