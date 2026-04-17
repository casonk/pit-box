#!/usr/bin/env python3
"""
Fetches ttyd's default HTML from a temporary instance and injects the
pit-box mobile toolbar, then saves the result to TARGET.

Usage: inject_toolbar.py [--port PORT] [--target PATH]
Called by rebuild_webservices.sh during ttyd rebuild.
"""
import argparse, sys, time, urllib.request

DEFAULT_PORT   = 7699
DEFAULT_TARGET = "/etc/pit-box/webterm/index.html"

# ---------------------------------------------------------------------------
# Toolbar CSS — fixed overlay, does not touch ttyd's own layout
# ---------------------------------------------------------------------------
TOOLBAR_CSS = """\
<style>
#pb-toolbar {
  position: fixed;
  bottom: 0; left: 0; right: 0;
  height: 52px;
  height: calc(52px + env(safe-area-inset-bottom, 0px));
  background: #161b22ee;
  border-top: 1px solid #30363d;
  display: flex;
  align-items: center;
  gap: 4px;
  padding: 0 8px;
  padding-bottom: env(safe-area-inset-bottom, 0px);
  overflow-x: auto;
  -webkit-overflow-scrolling: touch;
  scrollbar-width: none;
  z-index: 9999;
}
#pb-toolbar::-webkit-scrollbar { display: none; }
.pb-btn {
  flex-shrink: 0;
  min-width: 40px;
  padding: 6px 10px;
  background: #21262d;
  color: #c9d1d9;
  border: 1px solid #30363d;
  border-radius: 6px;
  font-size: 12px;
  font-family: ui-monospace, monospace;
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
  user-select: none;
  text-align: center;
  touch-action: manipulation;
}
.pb-btn:active { background: #1f6feb; border-color: #388bfd; color: #fff; }
.pb-sep {
  width: 1px; min-width: 1px; height: 30px;
  background: #30363d; flex-shrink: 0; margin: 0 2px;
}
</style>
"""

# ---------------------------------------------------------------------------
# Toolbar HTML — buttons use HTML entities for control characters so that
# getAttribute() returns the correct character values in all browsers
# ---------------------------------------------------------------------------
TOOLBAR_HTML = """\
<div id="pb-toolbar">
  <button class="pb-btn" data-send="&#x02;" title="tmux prefix">&#x2303;B</button>
  <button class="pb-btn" data-tmux="c"      title="new window">+win</button>
  <button class="pb-btn" data-tmux="n"      title="next window">next</button>
  <button class="pb-btn" data-tmux="p"      title="prev window">prev</button>
  <button class="pb-btn" data-tmux="w"      title="window list">list</button>
  <button class="pb-btn" data-tmux="&amp;"  title="kill window">kill</button>
  <div class="pb-sep"></div>
  <button class="pb-btn" data-send="&#x1b;[A">&#x2191;</button>
  <button class="pb-btn" data-send="&#x1b;[B">&#x2193;</button>
  <button class="pb-btn" data-send="&#x1b;[D">&#x2190;</button>
  <button class="pb-btn" data-send="&#x1b;[C">&#x2192;</button>
  <div class="pb-sep"></div>
  <button class="pb-btn" data-send="&#x09;"  title="tab completion">Tab</button>
  <button class="pb-btn" data-send="&#x1b;"  title="escape">Esc</button>
  <button class="pb-btn" data-send="&#x03;"  title="interrupt">&#x2303;C</button>
  <button class="pb-btn" data-send="&#x04;"  title="EOF / logout">&#x2303;D</button>
  <button class="pb-btn" data-send="&#x0c;"  title="clear screen">&#x2303;L</button>
</div>
"""

# ---------------------------------------------------------------------------
# WebSocket interceptor — must execute BEFORE ttyd's inline script so that
# the constructor is already patched when ttyd opens its connection
# ---------------------------------------------------------------------------
WS_INTERCEPTOR = """\
<script>
(function () {
  var _WS  = window.WebSocket;
  var sock = null;

  function PatchedWS(url, proto) {
    var ws = proto !== undefined ? new _WS(url, proto) : new _WS(url);
    if (url.indexOf('/ws') !== -1) { sock = ws; }
    return ws;
  }
  PatchedWS.prototype  = _WS.prototype;
  PatchedWS.CONNECTING = _WS.CONNECTING;
  PatchedWS.OPEN       = _WS.OPEN;
  PatchedWS.CLOSING    = _WS.CLOSING;
  PatchedWS.CLOSED     = _WS.CLOSED;
  window.WebSocket     = PatchedWS;

  function send(data) {
    if (!sock) { return; }
    if (sock.readyState === _WS.OPEN) {
      sock.send('0' + data);
    } else {
      sock.addEventListener('open', function () { sock.send('0' + data); }, { once: true });
    }
  }

  document.getElementById('pb-toolbar').addEventListener('click', function (e) {
    var btn = e.target.closest('[data-send],[data-tmux]');
    if (!btn) { return; }
    var raw = btn.getAttribute('data-send');
    if (raw !== null) { send(raw); return; }
    var chr = btn.getAttribute('data-tmux');
    if (chr !== null) {
      send('\\x02');
      setTimeout(function () { send(chr); }, 60);
    }
  });
}());
</script>
"""

MARKER = '<script type="text/javascript">'


def fetch_html(url: str, retries: int = 20) -> str:
    for i in range(retries):
        try:
            with urllib.request.urlopen(url, timeout=2) as r:
                return r.read().decode("utf-8")
        except Exception:
            time.sleep(0.3)
    raise RuntimeError(f"Could not fetch ttyd HTML from {url} after {retries} attempts")


def inject(html: str) -> str:
    if MARKER not in html:
        raise RuntimeError(f"Expected marker not found: {MARKER!r}")
    inject_block = TOOLBAR_CSS + TOOLBAR_HTML + WS_INTERCEPTOR
    html = html.replace(MARKER, inject_block + MARKER, 1)
    # Ensure iOS respects safe-area-inset so the toolbar clears the home bar.
    html = html.replace(
        'name="viewport" content="',
        'name="viewport" content="viewport-fit=cover, ',
        1,
    )
    return html


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--port",   type=int, default=DEFAULT_PORT)
    p.add_argument("--target", default=DEFAULT_TARGET)
    args = p.parse_args()

    url = f"http://127.0.0.1:{args.port}/"
    print(f"Fetching ttyd HTML from {url} …")
    html = fetch_html(url)
    print(f"Fetched {len(html):,} bytes — injecting toolbar …")
    html = inject(html)

    with open(args.target, "w", encoding="utf-8") as f:
        f.write(html)
    print(f"Saved → {args.target}")


if __name__ == "__main__":
    main()
