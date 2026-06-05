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
- In ttyd's generated page, injected scripts can run before ttyd creates
  `#terminal-container`. Toolbar code that wraps or resizes the terminal should
  watch for that DOM node and dispatch a resize event after font-size changes so
  xterm refits to the visible viewport.
- For WebTerm zoom, prefer changing xterm's `fontSize` option through
  `window.term` instead of CSS-transforming `#terminal-container`. Transforming
  the canvas can create side gutters and clipped columns because xterm's fit
  calculation still uses the untransformed layout box.
- For WebTerm page navigation buttons, remember the real service runs inside
  tmux. Drive tmux copy-mode through its key bindings (prefix+PageUp to enter
  copy-mode, PageDown/Escape while in copy-mode, and Ctrl-Up/Ctrl-Down for
  line scrolling) first, then keep xterm line scrolling and DOM viewport sync
  only as fallbacks for non-tmux render tests. xterm scrollback can be empty
  while tmux owns the visible history.
- To close only the current WebTerm browser terminal, detach the per-browser
  tmux client (`prefix d`) rather than killing a tmux window or the shared base
  session. Guard destructive toolbar actions with a visible two-click
  confirmation.
- Mobile browsers can block direct Clipboard API reads and cannot reliably
  select terminal canvas text. WebTerm clipboard controls should provide a
  native textarea panel backed by xterm scrollback for selection/copy and a
  visible-terminal DOM fallback plus a manual paste/send fallback when
  `navigator.clipboard.readText()` is denied.
- Run mobile WebTerm clipboard reads from the browser's normal `click` event,
  not the toolbar's pointer-up fast path; WebKit can reject asynchronous
  clipboard access outside that event. Keep denied-read paste fallback visibly
  distinct from the select/copy panel so users know to use native paste and
  then send.
- Mobile WebTerm toolbar buttons should handle touch/pointer activation in
  addition to normal `click`; terminal canvases and mobile browser chrome can
  make click-only handlers feel intermittent even when the desktop path works.
- Mobile WebTerm finger scrolling should be an explicit terminal gesture, not
  only native browser scrolling on `.xterm-viewport`. Prefer tmux mouse mode
  plus xterm's native touch-to-wheel handling: when apps such as Codex request
  mouse input, tmux forwards wheel events to the app; otherwise tmux enters
  copy-mode for shell scrollback. Browser-side fallback handlers must step
  aside when `.xterm.enable-mouse-events` is present, then use the loopback
  WebTerm API for non-mouse terminal states. The API should decide whether the
  foreground program is Codex-like and send Ctrl-Up/Ctrl-Down there; otherwise
  it should enter tmux copy-mode and run `send-keys -X` scroll commands. Do not
  send prefix+`[` or prefix+PageUp from the browser gesture path; failed or
  stale mode transitions can leak literal input or move shell command history.
  Cover both `touch*` and pointer events because mobile browser event delivery
  differs by engine and embedded terminal focus state. Use coordinate-based
  stage hit testing as a fallback because terminal canvas events can be
  retargeted. Keep xterm/DOM viewport synchronization as a fallback for
  generated-page tests.
- Mobile WebTerm fixed-position layouts should account for the on-screen
  keyboard with `visualViewport`: raise the terminal stage and bottom toolbar by
  the keyboard inset, refit xterm, and scroll the xterm viewport to the bottom
  when not in tmux copy-mode so the current prompt stays visible.
- Mobile WebTerm landscape layout needs its own compact toolbar sizing. A
  portrait-height three-row toolbar can consume nearly the entire screen after
  rotation; switch to a short horizontal-scroller toolbar under low viewport
  heights.
- WebTerm select/copy fallback panels should use a full-screen native textarea
  on phones. Half-height floating panels leave too little usable text area once
  mobile browser chrome, safe areas, and the terminal toolbar are present.
- When the web terminal uses both static pages and a loopback API, install and rebuild flows must deploy them together. Rebuilding only ttyd leaves the home page and live-terminal state UI stale even if the terminal itself updates.
- When a rebuild script is likely to be run from inside WebTerm, restart
  `ttyd` last. Restarting `ttyd` kills the browser terminal that is running the
  script, so any coupled API restart, service-file copy, or health check placed
  after the ttyd restart will never run.
- After restarting `pit-box-api`, poll the loopback endpoint for readiness
  instead of probing once. systemd can report a successful restart before the
  Python HTTP server has bound the port, producing a transient HTTP `000` even
  though the service is about to become healthy.
- When deriving "live terminals" from tmux, filter grouped sessions by the configured base session group as well as the `pb-` prefix. Shared hosts can have unrelated `pb-*` sessions, and the home page should not report them.
- When browser code falls back between pit-box API endpoints, treat non-2xx `fetch()` responses as failures explicitly. `fetch()` resolves on HTTP 404/500, and the home page can silently render empty state instead of falling back if the code only handles network errors.
- When serving ttyd's generated terminal page from a subpath such as `/term`,
  remember ttyd derives `/token` and `/ws` from `window.location.pathname`.
  The Caddy route must strip the subpath for `/term/token` and `/term/ws`, or
  the browser can render a blank terminal page after the token request 404s.
  Toolbar WebSocket interception should preserve ttyd's chosen base path and
  let Caddy handle the strip-prefix behavior.
- When using per-browser grouped tmux sessions, sync the disconnecting session's current window back to the base session before killing it. Otherwise every reconnect starts from the base session's stale default window, usually `0`.
- The canonical private hostnames for `pit-box` browser/admin surfaces belong in
  the sibling `wiring-harness` site registry. `settings.env` can keep local
  overrides for emergencies, but render/install flows should resolve
  `pit-box-webterm` and `pit-box-cockpit` from the shared registry first so the
  host inventory, DNS, and certificates stay aligned.
- When a browser surface moves from a repo-owned Caddy drop-in to
  `wiring-harness-caddy`, remove the old `/etc/caddy/Caddyfile.d/*.caddy`
  snippet before validating or reloading Caddy. Duplicate site blocks can block
  unrelated Caddy rebuilds, such as a WebTerm route refresh.
- The official Apache Guacamole Docker image runs as UID/GID `1001:1001`.
  On Fedora/Podman with SELinux, bind-mounted Guacamole config should use a
  private container label such as `:Z` and be owned by that container UID/GID
  rather than root-only permissions.
- Service login credentials introduced in `pit-box` should resolve through the
  sibling `auto-pass` repo where possible. Keep direct password settings as
  ignored emergency fallbacks, not the normal source of truth.
