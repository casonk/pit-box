#!/usr/bin/env python3
"""
Fetches ttyd's default HTML from a temporary instance, injects the pit-box
WebSocket interceptor and a floating home link, then saves the result to TARGET.

The terminal page is intentionally chrome-free; navigation happens via the
home page at /.  URL params drive automatic tmux actions on connect:
  ?window=N    — switch to tmux window N (ctrl+b N)
  ?action=new  — open a new tmux window (ctrl+b c)
  ?kill=N      — kill tmux window N (ctrl+b &, confirm, then redirect home)

Usage: inject_toolbar.py [--port PORT] [--target PATH]
Called by rebuild_webservices.sh during ttyd rebuild.
"""
import argparse, sys, time, urllib.request

DEFAULT_PORT   = 7699
DEFAULT_TARGET = "/etc/pit-box/webterm/index.html"

# ---------------------------------------------------------------------------
# Minimal chrome — just a floating home link; terminal fills the full screen
# ---------------------------------------------------------------------------
HOME_BUTTON_CSS = """\
<style>
#pb-home {
  position: fixed;
  top: max(8px, env(safe-area-inset-top));
  right: 10px;
  z-index: 9999;
  padding: 4px 11px;
  background: rgba(22, 27, 34, 0.75);
  color: #8b949e;
  border: 1px solid #30363d;
  border-radius: 6px;
  font-size: 14px;
  text-decoration: none;
  backdrop-filter: blur(6px);
  -webkit-backdrop-filter: blur(6px);
  -webkit-tap-highlight-color: transparent;
}
#pb-home:active { color: #c9d1d9; border-color: #8b949e; }
</style>
"""

HOME_BUTTON_HTML = """\
<a id="pb-home" href="/">&#x2302;</a>
"""

# ---------------------------------------------------------------------------
# WebSocket interceptor — patches window.WebSocket before ttyd's inline script
# so toolbar buttons can reuse the socket without a second tmux attachment.
# Also reads URL params to auto-execute tmux actions on connect.
# ---------------------------------------------------------------------------
WS_INTERCEPTOR = """\
<script>
(function () {
  var _WS  = window.WebSocket;
  var sock = null;

  var _p      = new URLSearchParams(window.location.search);
  var _window = _p.get('window');
  var _action = _p.get('action');

  function send(data) {
    if (!sock) { return; }
    if (sock.readyState === _WS.OPEN) {
      sock.send('0' + data);
    } else {
      sock.addEventListener('open', function () { sock.send('0' + data); }, { once: true });
    }
  }

  function execAction() {
    if (_window !== null) {
      send('\x02');
      setTimeout(function () { send(_window); }, 80);
    } else if (_action === 'new') {
      send('\x02');
      setTimeout(function () { send('c'); }, 80);
    }
  }

  function PatchedWS(url, proto) {
    // ttyd builds the WS URL relative to the serving path (e.g. /term/ws when
    // the page is at /term), but ttyd's WS handler only listens at /ws.
    // Normalize: strip any path prefix so the URL always ends at /ws.
    url = url.replace(/(wss?:\/\/[^/]+)(?:\/[^?#]*)?\/ws(\?[^#]*)?$/, '$1/ws$2');
    var ws = proto !== undefined ? new _WS(url, proto) : new _WS(url);
    if (url.indexOf('/ws') !== -1) {
      sock = ws;
      ws.addEventListener('open', function () {
        setTimeout(execAction, 900);
      }, { once: true });
    }
    return ws;
  }
  PatchedWS.prototype  = _WS.prototype;
  PatchedWS.CONNECTING = _WS.CONNECTING;
  PatchedWS.OPEN       = _WS.OPEN;
  PatchedWS.CLOSING    = _WS.CLOSING;
  PatchedWS.CLOSED     = _WS.CLOSED;
  window.WebSocket     = PatchedWS;
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
    inject_block = HOME_BUTTON_CSS + HOME_BUTTON_HTML + WS_INTERCEPTOR
    html = html.replace(MARKER, inject_block + MARKER, 1)
    # viewport-fit=cover enables env(safe-area-inset-*) on iOS notched devices.
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
    print(f"Fetched {len(html):,} bytes — injecting …")
    html = inject(html)

    with open(args.target, "w", encoding="utf-8") as f:
        f.write(html)
    print(f"Saved → {args.target}")


if __name__ == "__main__":
    main()
