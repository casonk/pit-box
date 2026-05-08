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

## Web terminal is a blank white page

Check:

1. `curl -sS http://127.0.0.1:7681/token` returns JSON from ttyd.
2. `/etc/caddy/Caddyfile.d/pit-box-webterm.caddy` routes `/term/token` and `/term/ws` through `uri strip_prefix /term` before proxying to ttyd.
3. rerun `./scripts/render_configs.sh` and `sudo ./scripts/rebuild_webservices.sh caddy` to redeploy the Caddy route.
4. hard-refresh the browser after Caddy reloads so the old failed terminal page is not cached.

## Web terminal loads but helper keys are missing

Check:

1. `/etc/pit-box/webterm/index.html` exists and contains `pb-toolbar`
2. rerun `sudo ./scripts/rebuild_webservices.sh ttyd` to redeploy the terminal page and refresh the coupled home-page API
3. hard-refresh the browser after the ttyd restart so the old page is not cached

## Web terminal zoom buttons clip the terminal

Check:

1. `/etc/pit-box/webterm/index.html` contains `termRef.options.fontSize`.
2. tap `1:1`, then `A+`; the top label should move from `17pt` to `18pt`.
3. hard-refresh the browser after `sudo ./scripts/rebuild_webservices.sh ttyd`; stale JavaScript can leave the old transform-based zoom active.

## Web terminal page navigation buttons do not scroll

Check:

1. `/etc/pit-box/webterm/index.html` contains `KEY_PAGE_UP`, `KEY_PAGE_DOWN`, `KEY_CTRL_UP`, and `KEY_CTRL_DOWN`, and does not contain `sendTmux('[')`.
2. `/etc/pit-box/ttyd_session.sh` contains `tmux set-option -t "$BASE_SESSION" mouse on` and `tmux set-option -t "$SESS" mouse on`.
3. `/etc/pit-box/webterm/index.html` contains `installTerminalTouchScroll`, `beginTerminalTouchScroll`, `isXtermMouseEventsActive`, `isPointInStage`, `pointermove`, `scrollTerminalsViaApi`, `scrollToTerminalLine`, `pointerup`, `data-page="bottom"`, and no `data-scroll` controls.
4. `/etc/pit-box/pit_box_api.py` contains `/api/terminals/scroll`, `pane_current_command`, `C-Up`, `copy-mode`, `send-keys`, and `-X` support; an empty `curl -X POST http://127.0.0.1:7682/api/terminals/scroll` should return HTTP 400, not 501 or 000.
5. drag one finger vertically in either direction in the terminal body; inside Codex the gesture should scroll Codex through Ctrl-Up/Ctrl-Down, and at a shell prompt it should enter tmux copy-mode without moving command history or typing `[` at the prompt.
6. if you are running the rebuild from inside WebTerm, `ttyd` will kill that browser terminal near the end of `sudo ./scripts/rebuild_webservices.sh ttyd`; that is expected after the API restart and health check have already run.
7. hard-refresh the browser after `sudo ./scripts/rebuild_webservices.sh ttyd`; stale JavaScript or a stale `pit-box-api` service can leave the old direct-key scrolling active.

## Web terminal toolbar fills the screen in landscape

Check:

1. `/etc/pit-box/webterm/index.html` contains `@media (orientation: landscape)` and `--pb-toolbar-h: 74px`.
2. rotate the phone to landscape; the bottom toolbar should become a compact horizontal scroller instead of three tall rows.
3. hard-refresh the browser after `sudo ./scripts/rebuild_webservices.sh ttyd`; stale CSS can leave the old portrait toolbar active.

## Web terminal keyboard covers the current prompt

Check:

1. `/etc/pit-box/webterm/index.html` contains `--pb-keyboard-offset`, `visualViewport`, and `installKeyboardInsetHandler`.
2. tap the terminal so the phone keyboard opens; the bottom toolbar and terminal stage should move above the keyboard and the terminal should refit.
3. hard-refresh the browser after `sudo ./scripts/rebuild_webservices.sh ttyd`; stale JavaScript can leave the old fixed-bottom layout active.

## Web terminal kill button does not close the current terminal

Check:

1. `/etc/pit-box/webterm/index.html` contains `data-kill="-terminal"` and `pb-confirm`.
2. tap `-kill` once and confirm it changes color; tap it a second time before the color resets.
3. hard-refresh the browser after `sudo ./scripts/rebuild_webservices.sh ttyd`; stale JavaScript can leave the old toolbar active.

## Web terminal select, copy, or paste does not work

Check:

1. `/etc/pit-box/webterm/index.html` contains `pb-clip-panel`, `inset: 0`, `collectBufferText`, `collectDomText`, and `data-clip-send`.
2. tap `sel`; a full-screen native text panel should open with terminal scrollback selected for mobile copy handles.
3. tap `paste`; if the browser blocks clipboard read access, paste into the native text panel and tap `send`.
4. hard-refresh the browser after `sudo ./scripts/rebuild_webservices.sh ttyd`; stale JavaScript can leave the old select-only toolbar active.

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

## RDP does not connect over VPN

Check:

1. WireGuard is connected on the phone and `10.8.0.1` is reachable.
2. `REMOTE_DESKTOP_ENABLED=true` and `sudo ./scripts/install_remote_desktop.sh` has been run.
3. `systemctl status xrdp` and `systemctl status xrdp-sesman` are healthy.
4. firewall rules were refreshed with `sudo ./scripts/configure_firewall.sh`.
5. the phone connects to `10.8.0.1:3389` or the `pit-box-rdp` private hostname, not the public WAN address.
6. the desktop account can log in locally and is not already blocked by the desktop session manager.

## Safari remote desktop does not load

Check:

1. WireGuard is connected on the phone.
2. `REMOTE_DESKTOP_WEB_ENABLED=true` and `sudo ./scripts/install_remote_desktop_gateway.sh` has been run.
3. `sudo systemctl status pit-box-guacamole.service pit-box-guacd.service` are healthy.
4. `sudo podman ps` shows the `pit-box-guacamole` and `pit-box-guacd` containers.
5. `sudo ss -ltnp | grep ':8090'` shows Guacamole bound on loopback.
6. Caddy has exactly one `desktop.*` site definition: either the shared wiring-harness block in `/etc/caddy/Caddyfile`, or the pit-box drop-in at `/etc/caddy/Caddyfile.d/pit-box-remote-desktop.caddy`, not both.
7. `./scripts/render_remote_desktop_gateway.sh` reports `Credential source: auto-pass:...`.
8. the iPhone has the current wiring-harness mTLS profile installed.

If `sudo ./scripts/rebuild_webservices.sh caddy` reports `ambiguous site
definition` for the desktop hostname, remove the stale pit-box drop-in by
rerunning:

```bash
sudo ./scripts/rebuild_webservices.sh caddy
```

The rebuild script removes `/etc/caddy/Caddyfile.d/pit-box-remote-desktop.caddy`
when the `pit-box-remote-desktop` registry entry uses
`ingress = "wiring-harness-caddy"`.

If the Guacamole container keeps restarting or nothing is listening on
`127.0.0.1:8090`, check the container state and logs:

```bash
sudo podman ps -a --filter name=pit-box-guac
sudo podman logs --tail=120 pit-box-guacamole
sudo podman logs --tail=80 pit-box-guacd
```

On Fedora/SELinux systems the rendered compose file should mount
`./guacamole-home:/etc/guacamole:ro,Z`, and the installer should own
`/etc/pit-box/remote-desktop/guacamole-home` as the Guacamole container
UID/GID, defaulting to `1001:1001`.

If the page loads but Guacamole says login failed, retrieve the expected
credential through auto-pass and rerender/reinstall the gateway:

```bash
cd ../auto-pass
PYTHONPATH=src python3 -m auto_pass --profile infra get pit-box/remote-desktop/guacamole
cd ../pit-box
./scripts/render_remote_desktop_gateway.sh
sudo ./scripts/install_remote_desktop_gateway.sh
```
