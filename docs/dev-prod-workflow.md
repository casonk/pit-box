# Dev / Prod Workflow

pit-box supports running a **development instance** (separate port, service names,
install path, and tmux session) alongside the live **production instance** on the
same machine. Changes are tested in dev before being promoted to prod.

## How it works

The `WEBTERM_ENV_SUFFIX` variable in `settings.env` controls all instance-specific
names. When it is empty (production default), everything uses the canonical names
(`ttyd.service`, `/etc/pit-box/`, `pit-box` session). When it is set to `-dev`, all
names gain that suffix (`ttyd-dev.service`, `/etc/pit-box-dev/`, `pit-box-dev` session).

Both `render_configs.sh` and `rebuild_webservices.sh` accept a `--settings FILE`
flag so you can target either environment without changing `settings.env`.

## One-time dev setup

```bash
# 1. Copy the dev settings template and fill it in.
cp settings.dev.env.example settings.dev.env
#    Edit settings.dev.env:
#      - uncomment the `source settings.env` line at the top
#      - set WEBTERM_HOSTNAME to your dev hostname
#      - adjust WEBTERM_PORT if 7691 conflicts with anything

# 2. Register the dev hostname in your wiring-harness or dnsmasq config so it
#    resolves over the VPN tunnel (same IP as prod, different hostname).

# 3. Render configs for dev.
scripts/render_configs.sh --settings settings.dev.env

# 4. Deploy the dev instance (requires sudo).
sudo scripts/rebuild_webservices.sh --settings settings.dev.env
```

The dev Caddy drop-in (`pit-box-webterm-dev.caddy`) is written to
`/etc/caddy/Caddyfile.d/` automatically, so both hostnames are served by the
same Caddy process.

## Day-to-day development workflow

```
edit source files
      │
      ▼
scripts/render_configs.sh --settings settings.dev.env
      │
      ▼
rebuild dev from the dev homepage (rebuild api / rebuild ttyd)
      │  OR from the terminal:
      │  sudo scripts/rebuild_webservices.sh --settings settings.dev.env api
      │
      ▼
test at https://webterm-dev.homeserver.vpn
      │
      ├── broken → fix and repeat
      │
      └── good  → git commit + push to dev branch
                         │
                         └── peer review / final check
                                   │
                                   └── merge dev → main
                                             │
                                             ▼
                                   render_configs.sh  (no --settings → prod)
                                   rebuild from prod homepage
                                   verify at https://webterm.homeserver.vpn
```

## Key rule

> **All code changes go to dev first. Production only receives changes that have
> already passed testing in the dev instance.**

Never run `render_configs.sh` or `rebuild_webservices.sh` against production
directly from an untested branch. The commit on `main` that you deploy to prod
should be the same commit you validated in dev.

## Port reference

| | Production | Development |
|---|---|---|
| ttyd | `WEBTERM_PORT` (default 7681) | `WEBTERM_PORT` in `settings.dev.env` (default 7691) |
| API | `WEBTERM_PORT + 1` (default 7682) | `WEBTERM_PORT + 1` (default 7692) |
| tmux session | `pit-box` | `pit-box-dev` |
| install path | `/etc/pit-box/` | `/etc/pit-box-dev/` |
| systemd units | `ttyd`, `pit-box-api` | `ttyd-dev`, `pit-box-api-dev` |
| Caddy drop-in | `pit-box-webterm.caddy` | `pit-box-webterm-dev.caddy` |
| dnsmasq conf | `pit-box-vpn.conf` | `pit-box-dev-vpn.conf` |

## Adding more environments

Add a `settings.qa.env` with `WEBTERM_ENV_SUFFIX=-qa` and a distinct port and
hostname. All scripts accept `--settings` so no code changes are needed.
