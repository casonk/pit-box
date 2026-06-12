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
- Distinguish WebTerm browser-client detach from tmux-window kill. When a
  visible-window kill is requested, send tmux's guarded `prefix+&` action
  through that exact browser WebSocket so it targets the window visible in
  that client; do not use `prefix d`, which only detaches the browser client.
  Label the action as a window kill and retain a visible two-tap confirmation.
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
- Ordinary mobile WebTerm toolbar buttons should prevent focus theft on
  pointer-down and refocus xterm after activation so the phone keyboard stays
  open. Clipboard select/paste panels are exceptions because they manage a
  native textarea.
- Do not auto-focus or auto-select the full WebTerm select/copy fallback
  textarea. Large programmatic textarea selections can make mobile browsers
  zoom aggressively; keep the textarea font at least 16px and enforce the
  intended mobile viewport scale.
- Mobile WebTerm finger scrolling should be an explicit terminal gesture, not
  only native browser scrolling on `.xterm-viewport`. The loopback WebTerm API
  handles scroll for all foreground states: Codex/node gets Ctrl-Up/Ctrl-Down,
  everything else enters tmux copy-mode. Do NOT gate the touch-scroll handler on
  `isXtermMouseEventsActive()` / `.xterm.enable-mouse-events` — `ttyd_session.sh`
  sets `tmux mouse on` unconditionally, which permanently asserts that flag and
  silently disables the entire touch-scroll path. Let the API decide how to scroll.
  Cover both `touch*` and pointer events because mobile browser event delivery
  differs by engine and embedded terminal focus state. Use coordinate-based
  stage hit testing as a fallback because terminal canvas events can be
  retargeted. Keep xterm/DOM viewport synchronization as a fallback for
  generated-page tests.
- In WebTerm touch-scroll handlers, call `event.stopPropagation()` at the very
  start of `moveTerminalTouchScroll` — before the minimum-delta guard — so xterm's
  mouse-event pipeline never receives any terminal touch-move, regardless of
  gesture size. Stopping propagation only after crossing the threshold lets small
  moves reach xterm, which then sends mouse events to tmux; after our API enters
  copy-mode, xterm's `pointerup` mouse-up exits copy-mode and causes the
  frozen/snapping effect. Also stop propagation on `pointerup`/`touchend` when a
  tmux scroll was initiated (`touchScroll.tmuxStarted`) so xterm's pointer-up
  doesn't silently exit copy-mode either.
- When the mobile keyboard opens, always scroll the WebTerm to the terminal bottom,
  even when tmux copy-mode is active. Gate on keyboard inset (`next > 0`) only, not
  on `!tmuxCopyModeLikely`. When copy-mode is active, call `bottomTmuxCopyMode()`
  first and delay `scrollXtermToBottom` by ~300 ms to allow copy-mode exit and
  redraw before the scroll.
- Mobile WebTerm fixed-position layouts should account for the on-screen
  keyboard with `visualViewport`: raise the terminal stage and bottom toolbar by
  the keyboard inset, refit xterm, and scroll the xterm viewport to the bottom
  when not in tmux copy-mode so the current prompt stays visible.
- Mobile WebTerm landscape layout needs its own compact toolbar sizing. A
  portrait-height three-row toolbar can consume nearly the entire screen after
  rotation; switch to a short horizontal-scroller toolbar under low viewport
  heights. Keep each button group horizontal in that compact landscape mode:
  stacking a group vertically inside the short toolbar can push lower controls
  such as the guarded `-win` kill button out of view.
- WebTerm select/copy fallback panels should use a full-screen native textarea
  on phones. Half-height floating panels leave too little usable text area once
  mobile browser chrome, safe areas, and the terminal toolbar are present.
- The WebTerm select panel textarea must be focused (with `inputmode="none"`) to
  be touch-scrollable on iOS. iOS Safari will not scroll an unfocused textarea
  inside a `position: fixed` container via touch. `inputmode="none"` prevents the
  keyboard from appearing on focus while still enabling touch-scroll and text
  selection. Do not focus without setting `inputmode="none"` first — the prior
  lesson about not auto-focusing still applies (bare focus causes aggressive zoom).
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
- The WebTerm select/copy clip panel must not cover the toolbar. `#pb-clip-panel`
  uses `inset: 0` by default, which places it over the toolbar and blocks toolbar
  buttons (zoom, font size, etc.) even though `pb-sel-mode` is active. Fix:
  constrain the clip panel's bottom to `calc(var(--pb-toolbar-h) + var(--pb-keyboard-offset) + env(safe-area-inset-bottom))`
  and raise `#pb-toolbar` z-index above the panel so toolbar controls remain
  reachable in all overlay states. Including `env(safe-area-inset-bottom)` is
  essential — the toolbar's `padding-bottom: max(6px, env(safe-area-inset-bottom))`
  makes its actual rendered height exceed `--pb-toolbar-h` on iPhones with a home
  bar, so the clip panel would overlap the first toolbar row (where A-/A+ live)
  if the safe area offset is omitted.
- The WebTerm clip panel textarea font size must track the terminal font size. On
  panel open, set `area.style.fontSize = Math.max(16, readFontSize()) + 'px'` so
  the text appears at the same scale as the terminal (min 16px prevents iOS
  auto-zoom on focus). In `applyFontSize`, when the panel is open, apply the same
  update so A-/A+ changes are immediately visible in the textarea rather than
  appearing to do nothing until the panel is closed.
- When validating scripts that support `WEBTERM_ENV_SUFFIX`, check the
  suffix-aware service/container variables or rendered-name construction rather
  than only prod literals. Dev/prod Quadlet names such as
  `pit-box-guacamole${WEBTERM_ENV_SUFFIX}.service` should remain verifiable
  without causing false validation failures.
