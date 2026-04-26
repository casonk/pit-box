#!/usr/bin/env python3
"""
Fetches ttyd's default HTML from a temporary instance, injects the pit-box
terminal controls, and saves the result to TARGET.

The generated page keeps ttyd's own HTML/CSS/JS but adds:
  - a top bar with Home + font scaling
  - a bottom helper bar for tmux actions and control keys
  - direct viewport scrolling helpers for buffer scrollback
  - URL-driven tmux actions on connect (?window=N / ?action=new)
"""
import argparse
import time
import urllib.request

DEFAULT_PORT = 7699
DEFAULT_TARGET = "/etc/pit-box/webterm/index.html"

INJECTED_CSS = """\
<style>
:root {
  --pb-scale: 1;
  --pb-topbar-h: 52px;
  --pb-toolbar-h: 90px;
}
html, body { overflow: hidden; }
#terminal-container {
  position: fixed;
  top: calc(var(--pb-topbar-h) + env(safe-area-inset-top));
  left: 0;
  width: calc(100% / var(--pb-scale));
  height: calc((100% - var(--pb-topbar-h) - var(--pb-toolbar-h) - env(safe-area-inset-top) - env(safe-area-inset-bottom)) / var(--pb-scale));
  transform: scale(var(--pb-scale));
  transform-origin: top left;
  background: #0d1117;
}
#pb-topbar,
#pb-toolbar {
  position: fixed;
  left: 0;
  right: 0;
  z-index: 9999;
  display: flex;
  align-items: center;
  gap: 6px;
  padding-left: 8px;
  padding-right: 8px;
  background: rgba(22, 27, 34, 0.9);
  backdrop-filter: blur(8px);
  -webkit-backdrop-filter: blur(8px);
}
#pb-topbar {
  top: 0;
  min-height: var(--pb-topbar-h);
  padding-top: max(6px, env(safe-area-inset-top));
  border-bottom: 1px solid #30363d;
}
#pb-toolbar {
  bottom: 0;
  min-height: var(--pb-toolbar-h);
  padding-top: 6px;
  padding-bottom: max(6px, env(safe-area-inset-bottom));
  flex-direction: column;
  align-items: stretch;
  gap: 5px;
  border-top: 1px solid #30363d;
}
.pb-row {
  display: flex;
  align-items: center;
  gap: 6px;
  overflow-x: auto;
  -webkit-overflow-scrolling: touch;
  scrollbar-width: none;
}
.pb-row::-webkit-scrollbar { display: none; }
.pb-grow { flex: 1 1 auto; }
.pb-btn,
.pb-link {
  flex: 0 0 auto;
  min-width: 50px;
  padding: 9px 13px;
  background: #21262d;
  color: #c9d1d9;
  border: 1px solid #30363d;
  border-radius: 10px;
  font-size: 15px;
  font-family: ui-monospace, monospace;
  line-height: 1;
  text-decoration: none;
  text-align: center;
  cursor: pointer;
  user-select: none;
  -webkit-tap-highlight-color: transparent;
  touch-action: manipulation;
}
.pb-btn:active,
.pb-link:active { background: #1f6feb; border-color: #388bfd; color: #fff; }
.pb-label {
  flex: 0 0 auto;
  min-width: 52px;
  color: #8b949e;
  font-size: 11px;
  text-align: center;
  font-family: ui-monospace, monospace;
}
.pb-sep {
  width: 1px;
  min-width: 1px;
  height: 32px;
  background: #30363d;
  flex: 0 0 auto;
}
.xterm-viewport {
  overflow-y: auto !important;
  -webkit-overflow-scrolling: touch;
  overscroll-behavior: contain;
  touch-action: pan-y;
}
.xterm-screen,
.xterm canvas {
  touch-action: pan-y;
}
</style>
"""

INJECTED_HTML = """\
<div id="pb-topbar">
  <a class="pb-link" href="/">Home</a>
  <button class="pb-btn" data-scale="-0.10">A-</button>
  <div class="pb-label" id="pb-scale-label">100%</div>
  <button class="pb-btn" data-scale="0.10">A+</button>
  <button class="pb-btn" data-scale="reset">1:1</button>
  <div class="pb-grow"></div>
</div>
<div id="pb-toolbar">
  <div class="pb-row">
    <button class="pb-btn" data-tmux="c">+win</button>
    <button class="pb-btn" data-tmux="n">next</button>
    <button class="pb-btn" data-tmux="p">prev</button>
    <button class="pb-btn" data-tmux="w">list</button>
    <div class="pb-sep"></div>
    <button class="pb-btn" data-send="&#x1b;[A">&#x2191;</button>
    <button class="pb-btn" data-send="&#x1b;[B">&#x2193;</button>
    <button class="pb-btn" data-send="&#x1b;[D">&#x2190;</button>
    <button class="pb-btn" data-send="&#x1b;[C">&#x2192;</button>
  </div>
  <div class="pb-row">
    <button class="pb-btn" data-send="&#x09;">Tab</button>
    <button class="pb-btn" data-send="&#x1b;">Esc</button>
    <button class="pb-btn" data-send="&#x03;">Ctrl+C</button>
    <button class="pb-btn" data-send="&#x04;">Ctrl+D</button>
    <button class="pb-btn" data-send="&#x0c;">Ctrl+L</button>
    <div class="pb-sep"></div>
    <button class="pb-btn" data-scroll="-0.85">PgUp</button>
    <button class="pb-btn" data-scroll="0.85">PgDn</button>
    <button class="pb-btn" data-scroll="bottom">Bottom</button>
  </div>
</div>
"""

WS_INTERCEPTOR = """\
<script>
(function () {
  var SCALE_KEY = 'pb-terminal-scale';
  var SCALE_MIN = 0.8;
  var SCALE_MAX = 1.6;
  var _WS = window.WebSocket;
  var sock = null;

  var params = new URLSearchParams(window.location.search);
  var targetWindow = params.get('window');
  var action = params.get('action');

  function clamp(value, min, max) {
    return Math.max(min, Math.min(max, value));
  }

  function readScale() {
    var saved = parseFloat(window.localStorage.getItem(SCALE_KEY) || '1');
    if (!isFinite(saved)) { return 1; }
    return clamp(saved, SCALE_MIN, SCALE_MAX);
  }

  function updateScaleLabel(scale) {
    var label = document.getElementById('pb-scale-label');
    if (label) {
      label.textContent = Math.round(scale * 100) + '%';
    }
  }

  function applyScale(scale) {
    var next = clamp(scale, SCALE_MIN, SCALE_MAX);
    document.documentElement.style.setProperty('--pb-scale', next.toFixed(2));
    window.localStorage.setItem(SCALE_KEY, String(next));
    updateScaleLabel(next);
  }

  function adjustScale(delta) {
    applyScale(readScale() + delta);
  }

  function resetScale() {
    applyScale(1);
  }

  function findViewport() {
    return document.querySelector('.xterm-viewport');
  }

  function scrollViewportBy(multiplier) {
    var viewport = findViewport();
    if (!viewport) { return; }
    viewport.scrollTop += viewport.clientHeight * multiplier;
  }

  function scrollViewportBottom() {
    var viewport = findViewport();
    if (!viewport) { return; }
    viewport.scrollTop = viewport.scrollHeight;
  }

  function send(data) {
    if (!sock) { return; }
    if (sock.readyState === _WS.OPEN) {
      sock.send('0' + data);
    } else {
      sock.addEventListener('open', function () { sock.send('0' + data); }, { once: true });
    }
  }

  function sendTmux(command) {
    send('\\x02');
    setTimeout(function () { send(command); }, 80);
  }

  function execAction() {
    if (targetWindow !== null) {
      sendTmux(targetWindow);
    } else if (action === 'new') {
      sendTmux('c');
    } else if (action === 'sessions') {
      sendTmux('s');
    }
    if (window.location.search) {
      history.replaceState(null, '', window.location.pathname);
    }
  }

  function handleControlClick(button) {
    var scale = button.getAttribute('data-scale');
    if (scale !== null) {
      if (scale === 'reset') {
        resetScale();
      } else {
        adjustScale(parseFloat(scale || '0'));
      }
      return;
    }

    var scroll = button.getAttribute('data-scroll');
    if (scroll !== null) {
      if (scroll === 'bottom') {
        scrollViewportBottom();
      } else {
        scrollViewportBy(parseFloat(scroll || '0'));
      }
      return;
    }

    var raw = button.getAttribute('data-send');
    if (raw !== null) {
      send(raw);
      return;
    }

    var tmux = button.getAttribute('data-tmux');
    if (tmux !== null) {
      sendTmux(tmux);
    }
  }

  function normalizeWsUrl(url) {
    return url.replace(/(wss?:\\/\\/[^/]+)(?:\\/[^?#]*)?\\/ws(\\?[^#]*)?$/, '$1/ws$2');
  }

  function PatchedWS(url, proto) {
    var normalized = normalizeWsUrl(url);
    var ws = proto !== undefined ? new _WS(normalized, proto) : new _WS(normalized);
    if (normalized.indexOf('/ws') !== -1) {
      sock = ws;
      ws.addEventListener('open', function () {
        setTimeout(execAction, 900);
      }, { once: true });
    }
    return ws;
  }

  PatchedWS.prototype = _WS.prototype;
  PatchedWS.CONNECTING = _WS.CONNECTING;
  PatchedWS.OPEN = _WS.OPEN;
  PatchedWS.CLOSING = _WS.CLOSING;
  PatchedWS.CLOSED = _WS.CLOSED;
  window.WebSocket = PatchedWS;

  document.addEventListener('click', function (event) {
    var button = event.target.closest('[data-send],[data-tmux],[data-scale],[data-scroll]');
    if (!button) { return; }
    event.preventDefault();
    handleControlClick(button);
  });

  // Pinch-to-zoom
  var _pinchDist0 = 0;
  var _pinchScale0 = 1;
  document.addEventListener('touchstart', function (e) {
    if (e.touches.length === 2) {
      _pinchDist0 = Math.hypot(
        e.touches[1].clientX - e.touches[0].clientX,
        e.touches[1].clientY - e.touches[0].clientY
      );
      _pinchScale0 = readScale();
    }
  }, { passive: true });
  document.addEventListener('touchmove', function (e) {
    if (e.touches.length !== 2 || _pinchDist0 === 0) { return; }
    var dist = Math.hypot(
      e.touches[1].clientX - e.touches[0].clientX,
      e.touches[1].clientY - e.touches[0].clientY
    );
    applyScale(_pinchScale0 * dist / _pinchDist0);
  }, { passive: true });
  document.addEventListener('touchend', function (e) {
    if (e.touches.length < 2) { _pinchDist0 = 0; }
  }, { passive: true });

  applyScale(readScale());
}());
</script>
"""

MARKER = '<script type="text/javascript">'


def fetch_html(url: str, retries: int = 20) -> str:
    for _ in range(retries):
        try:
            with urllib.request.urlopen(url, timeout=2) as response:
                return response.read().decode("utf-8")
        except Exception:
            time.sleep(0.3)
    raise RuntimeError(f"Could not fetch ttyd HTML from {url} after {retries} attempts")


def inject(html: str) -> str:
    if MARKER not in html:
        raise RuntimeError(f"Expected marker not found: {MARKER!r}")
    injected = INJECTED_CSS + INJECTED_HTML + WS_INTERCEPTOR
    html = html.replace(MARKER, injected + MARKER, 1)
    return html.replace(
        'name="viewport" content="',
        'name="viewport" content="viewport-fit=cover, ',
        1,
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    parser.add_argument("--target", default=DEFAULT_TARGET)
    args = parser.parse_args()

    url = f"http://127.0.0.1:{args.port}/"
    print(f"Fetching ttyd HTML from {url} ...")
    html = fetch_html(url)
    print(f"Fetched {len(html):,} bytes - injecting ...")
    rendered = inject(html)

    with open(args.target, "w", encoding="utf-8") as handle:
        handle.write(rendered)
    print(f"Saved -> {args.target}")


if __name__ == "__main__":
    main()
