# LESSONSLEARNED.md

Tracked durable lessons for `pit-box`.
Unlike `CHATHISTORY.md`, this file should keep only reusable lessons that should change how future sessions work in this repo.

## How To Use

- Read this file after `AGENTS.md` and before `CHATHISTORY.md` when resuming work.
- Add lessons that generalize beyond a single session.
- Keep entries concise and action-oriented.
- Do not use this file for transient status updates or full session logs.

## Lessons

- Before adding a new reverse proxy (nginx, caddy, etc.) for a web service, check what is already listening on port 80/443 with `ss -tlnp | grep ':80\|:443'` and `systemctl list-units --type=service --state=running | grep -iE 'http|web|caddy|apache'`. This machine runs Caddy as the wiring-harness reverse proxy; all new internal services should be wired in via a Caddyfile.d drop-in rather than installing a competing proxy.

- Document the repository around its real execution, curation, or integration flow instead of only the top-level folder list.
- Keep local-only, private, reference-only, or generated boundaries explicit so published or runtime behavior is not confused with offline material or non-committable inputs.
- Re-run repo-appropriate validation after changing generated artifacts, diagrams, workflows, or other CI-facing files so formatting and compatibility issues are caught before push.
- `secrets/`, `build/`, and `dist/` are gitignored runtime outputs — never commit their contents. Only `.gitkeep` and usage documentation inside `secrets/` belong in version control. If any real key or IP address leaks into a commit, treat it as compromised immediately and rotate before anything else.
- When bootstrapping SSH access for a new client (e.g. iPhone), generate a dedicated ed25519 key pair, add the public key to `~/.ssh/authorized_keys`, and transfer the private key to the device via the snowbridge SMB share. Delete the key from the share immediately after import. Never reuse server host keys as client identity keys.
- Apply pit-box SSH hardening (key-only, no password auth, no root login) via `/etc/ssh/sshd_config.d/90-pit-box-hardening.conf` before exposing sshd to any network.
- Prefer generating the custom ttyd web page from the locally installed ttyd assets instead of treating `index.html` as a static artifact. The helper toolbar is sensitive to ttyd's bundled HTML shape, so install/rebuild flows should regenerate `/etc/pit-box/webterm/index.html` against the current ttyd version, with the repo copy only as a safety fallback.
