#!/usr/bin/env python3
"""
Fetches ttyd's default HTML from a temporary instance, injects the pit-box
terminal controls, and saves the result to TARGET.

The generated page keeps ttyd's own HTML/CSS/JS but adds:
  - a top bar with Home + font scaling
  - a bottom helper bar for tmux actions, control keys, and guarded window kill
  - xterm scrollback helpers for page navigation
  - URL-driven tmux actions on connect (?window=N / ?action=new)
"""
import argparse
import re
import time
import urllib.request

DEFAULT_PORT = 7699
DEFAULT_TARGET = "/etc/pit-box/webterm/index.html"
VIEWPORT_META = (
    '<meta name="viewport" content="width=device-width, initial-scale=1.0, '
    'viewport-fit=cover, maximum-scale=1.0, user-scalable=no">'
)

INJECTED_CSS = """\
<style>
:root {
  --pb-topbar-h: 52px;
  --pb-toolbar-h: 260px;
  --pb-keyboard-offset: 0px;
}
html, body { overflow: hidden; }
#pb-stage {
  position: fixed;
  top: calc(var(--pb-topbar-h) + env(safe-area-inset-top));
  right: 0;
  bottom: calc(var(--pb-toolbar-h) + var(--pb-keyboard-offset) + env(safe-area-inset-bottom));
  left: 0;
  overflow: hidden;
  background: #0d1117;
}
#terminal-container {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  margin: 0;
  transform: none;
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
  bottom: var(--pb-keyboard-offset);
  min-height: var(--pb-toolbar-h);
  padding-top: 12px;
  padding-bottom: max(12px, env(safe-area-inset-bottom));
  flex-direction: column;
  align-items: stretch;
  gap: 10px;
  border-top: 1px solid #30363d;
}
.pb-row {
  display: flex;
  align-items: center;
  gap: 12px;
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
  pointer-events: auto;
  user-select: none;
  -webkit-tap-highlight-color: transparent;
  touch-action: manipulation;
}
.pb-btn:active,
.pb-link:active { background: #1f6feb; border-color: #388bfd; color: #fff; }
#pb-toolbar .pb-btn.pb-confirm {
  background: #8b1d1d;
  border-color: #f85149;
  color: #fff;
}
#pb-toolbar .pb-btn {
  min-width: 100px;
  padding: 18px 26px;
  border-radius: 14px;
  font-size: 30px;
}
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
  height: 64px;
  background: #30363d;
  flex: 0 0 auto;
}
.xterm-viewport {
  overflow-y: auto !important;
  -webkit-overflow-scrolling: touch;
  overscroll-behavior: contain;
  touch-action: none;
}
.xterm-screen,
.xterm canvas {
  touch-action: none;
}
body.pb-sel-mode .xterm-rows,
body.pb-sel-mode .xterm-screen,
body.pb-sel-mode .xterm canvas {
  user-select: text !important;
  -webkit-user-select: text !important;
  touch-action: none !important;
}
.pb-btn.pb-active { background: #1f6feb; border-color: #388bfd; color: #fff; }
#pb-clip-panel {
  position: fixed;
  inset: 0;
  z-index: 10001;
  display: none;
  flex-direction: column;
  gap: 10px;
  padding: max(12px, env(safe-area-inset-top)) 10px max(12px, env(safe-area-inset-bottom));
  background: #0d1117;
}
#pb-clip-panel.pb-open { display: flex; }
#pb-clip-heading {
  flex: 0 0 auto;
  display: flex;
  flex-direction: column;
  gap: 4px;
  color: #c9d1d9;
  font-family: ui-monospace, monospace;
}
#pb-clip-title { font-size: 20px; }
#pb-clip-help { color: #8b949e; font-size: 14px; }
#pb-clip-text {
  width: 100%;
  flex: 1 1 auto;
  min-height: 0;
  padding: 12px;
  resize: none;
  overflow: auto;
  background: #010409;
  color: #c9d1d9;
  border: 1px solid #30363d;
  border-radius: 10px;
  font-family: ui-monospace, monospace;
  font-size: 18px;
  line-height: 1.35;
  user-select: text;
  -webkit-user-select: text;
  touch-action: auto;
}
#pb-clip-actions {
  flex: 0 0 auto;
  display: flex;
  align-items: center;
  gap: 8px;
}
#pb-clip-actions .pb-btn {
  flex: 1 1 0;
  min-width: 76px;
  padding: 18px 14px;
  border-radius: 10px;
  font-size: 20px;
}
#pb-clip-panel[data-mode="select"] [data-clip-send],
#pb-clip-panel[data-mode="paste"] [data-clip-copy] { display: none; }
@media (orientation: landscape) and (max-height: 520px) {
  :root {
    --pb-topbar-h: 40px;
    --pb-toolbar-h: 74px;
  }
  #pb-topbar {
    min-height: var(--pb-topbar-h);
    padding-top: max(4px, env(safe-area-inset-top));
  }
  #pb-toolbar {
    min-height: var(--pb-toolbar-h);
    padding-top: 6px;
    padding-bottom: max(6px, env(safe-area-inset-bottom));
    flex-direction: row;
    align-items: center;
    overflow-x: auto;
    overflow-y: hidden;
    gap: 8px;
  }
  #pb-toolbar .pb-row {
    flex: 0 0 auto;
    gap: 7px;
    overflow: visible;
  }
  .pb-btn,
  .pb-link {
    min-width: 44px;
    padding: 8px 10px;
    border-radius: 8px;
    font-size: 13px;
  }
  #pb-toolbar .pb-btn {
    min-width: 58px;
    padding: 10px 12px;
    border-radius: 9px;
    font-size: 16px;
  }
  .pb-label {
    min-width: 44px;
    font-size: 10px;
  }
  .pb-sep {
    height: 34px;
  }
}
</style>
"""

INJECTED_HTML = """\
<div id="pb-topbar">
  <a class="pb-link" href="/">Home</a>
  <button class="pb-btn" data-font="-1">A-</button>
  <div class="pb-label" id="pb-font-label">17pt</div>
  <button class="pb-btn" data-font="1">A+</button>
  <button class="pb-btn" data-font="reset">1:1</button>
  <div class="pb-grow"></div>
</div>
<div id="pb-toolbar">
  <div class="pb-row">
    <button class="pb-btn" data-tmux="c">+win</button>
    <button class="pb-btn" data-tmux="n">next</button>
    <button class="pb-btn" data-tmux="p">prev</button>
    <button class="pb-btn" data-tmux="w">list</button>
    <div class="pb-sep"></div>
    <a class="pb-btn" href="/">home</a>
    <button class="pb-btn" data-kill="-window">-win</button>
    <div class="pb-sep"></div>
    <button class="pb-btn pb-sel-btn" id="pb-sel-btn" data-sel-mode>sel</button>
    <button class="pb-btn" data-copy-sel>copy</button>
    <button class="pb-btn" data-paste>paste</button>
  </div>
  <div class="pb-row">
    <button class="pb-btn" data-send="&#x09;">Tab</button>
    <button class="pb-btn" data-send="&#x1b;">Esc</button>
    <button class="pb-btn" data-send="&#x03;">Ctrl+C</button>
    <button class="pb-btn" data-send="&#x04;">Ctrl+D</button>
    <button class="pb-btn" data-send="&#x0c;">Ctrl+L</button>
  </div>
  <div class="pb-row">
    <button class="pb-btn" data-page="-1">PgUp</button>
    <button class="pb-btn" data-page="1">PgDn</button>
    <button class="pb-btn" data-page="bottom">Bottom</button>
    <div class="pb-sep"></div>
    <button class="pb-btn" data-send="&#x1b;[A">&#x2191;</button>
    <button class="pb-btn" data-send="&#x1b;[B">&#x2193;</button>
    <button class="pb-btn" data-send="&#x1b;[D">&#x2190;</button>
    <button class="pb-btn" data-send="&#x1b;[C">&#x2192;</button>
  </div>
  <!-- optional paste-input row: uncomment to enable a native text field for paste/type
  <div class="pb-row">
    <input class="pb-input" type="text" id="pb-input"
      autocomplete="off" autocorrect="off" autocapitalize="none" spellcheck="false"
      placeholder="paste or type, then send">
    <button class="pb-btn" data-input-send>&#x23CE;</button>
  </div>
  -->
</div>
<div id="pb-clip-panel" aria-hidden="true">
  <div id="pb-clip-heading">
    <strong id="pb-clip-title">Clipboard</strong>
    <span id="pb-clip-help"></span>
  </div>
  <textarea id="pb-clip-text"
    autocomplete="off" autocorrect="off" autocapitalize="none" spellcheck="false"></textarea>
  <div id="pb-clip-actions">
    <button class="pb-btn" data-clip-copy>copy</button>
    <button class="pb-btn" data-clip-send>send</button>
    <button class="pb-btn" data-clip-close>close</button>
  </div>
</div>
"""

WS_INTERCEPTOR = """\
<script>
(function () {
  var FONT_KEY = 'pb-terminal-font-size';
  var FONT_DEFAULT = 17;
  var FONT_MIN = 10;
  var FONT_MAX = 30;
  var _WS = window.WebSocket;
  var sock = null;
  var termRef = null;
  var killConfirmTimer = null;
  var lastPointerControlAt = 0;
  var touchScroll = null;
  var activeScrollPointerId = null;
  var keyboardInsetTimer = null;
  var lastKeyboardOffset = -1;
  var tmuxCopyModeLikely = false;
  var KEY_ESC = '\\x1b';
  var KEY_PAGE_UP = '\\x1b[5~';
  var KEY_PAGE_DOWN = '\\x1b[6~';
  var KEY_CTRL_UP = '\\x1b[1;5A';
  var KEY_CTRL_DOWN = '\\x1b[1;5B';

  var params = new URLSearchParams(window.location.search);
  var targetWindow = params.get('window');
  var action = params.get('action');

  function clamp(value, min, max) {
    return Math.max(min, Math.min(max, value));
  }

  function readFontSize() {
    var saved = parseFloat(window.localStorage.getItem(FONT_KEY) || String(FONT_DEFAULT));
    if (!isFinite(saved)) { return FONT_DEFAULT; }
    return Math.round(clamp(saved, FONT_MIN, FONT_MAX));
  }

  function updateFontLabel(fontSize) {
    var label = document.getElementById('pb-font-label');
    if (label) {
      label.textContent = Math.round(fontSize) + 'pt';
    }
  }

  // ttyd creates #terminal-container after this script runs. Keep watching so
  // the generated page and fallback page both use the same fixed viewport.
  function ensureStage() {
    var terminal = document.getElementById('terminal-container');
    if (!terminal) { return false; }

    var stage = document.getElementById('pb-stage');
    if (!stage) {
      stage = document.createElement('div');
      stage.id = 'pb-stage';
      terminal.parentNode.insertBefore(stage, terminal);
    }
    if (terminal.parentNode !== stage) {
      stage.appendChild(terminal);
    }
    return true;
  }

  function applyFontToTerminal(fontSize) {
    if (!termRef || !termRef.options) { return; }
    termRef.options.fontSize = fontSize;
  }

  function installTermWatcher() {
    if (Object.prototype.hasOwnProperty.call(window, 'term')) {
      termRef = window.term;
      applyFontToTerminal(readFontSize());
      return;
    }
    Object.defineProperty(window, 'term', {
      configurable: true,
      get: function () {
        return termRef;
      },
      set: function (value) {
        termRef = value;
        applyFontToTerminal(readFontSize());
      }
    });
  }

  function watchStage() {
    ensureStage();
    if (!window.MutationObserver) { return; }
    var observer = new MutationObserver(function () {
      ensureStage();
    });
    observer.observe(document.documentElement, { childList: true, subtree: true });
  }

  function dispatchResize() {
    if (typeof Event === 'function') {
      window.dispatchEvent(new Event('resize'));
      return;
    }
    var event = document.createEvent('UIEvents');
    event.initUIEvent('resize', true, false, window, 0);
    window.dispatchEvent(event);
  }

  function scheduleTerminalResize() {
    ensureStage();
    window.requestAnimationFrame(function () {
      if (termRef && typeof termRef.fit === 'function') {
        termRef.fit();
      }
      dispatchResize();
      window.setTimeout(function () {
        if (termRef && typeof termRef.fit === 'function') {
          termRef.fit();
        }
        dispatchResize();
      }, 120);
    });
  }

  function scrollXtermToBottom() {
    var viewport = findViewport();
    if (termRef && typeof termRef.scrollToBottom === 'function') {
      termRef.scrollToBottom();
    }
    if (!viewport) { return; }
    window.requestAnimationFrame(function () {
      setViewportScrollTop(viewport, viewport.scrollHeight);
    });
  }

  function setKeyboardOffset(offset) {
    var next = Math.max(0, Math.round(offset || 0));
    if (next < 80) { next = 0; }
    if (next === lastKeyboardOffset) { return; }
    lastKeyboardOffset = next;
    document.documentElement.style.setProperty('--pb-keyboard-offset', next + 'px');
    document.body.classList.toggle('pb-keyboard-active', next > 0);
    scheduleTerminalResize();
    if (next > 0 && !tmuxCopyModeLikely) {
      window.setTimeout(scrollXtermToBottom, 160);
    }
  }

  function updateKeyboardInset() {
    var viewport = window.visualViewport;
    if (!viewport) {
      setKeyboardOffset(0);
      return;
    }
    setKeyboardOffset(window.innerHeight - viewport.height - viewport.offsetTop);
  }

  function scheduleKeyboardInsetUpdate() {
    if (keyboardInsetTimer !== null) {
      window.cancelAnimationFrame(keyboardInsetTimer);
    }
    keyboardInsetTimer = window.requestAnimationFrame(function () {
      keyboardInsetTimer = null;
      updateKeyboardInset();
    });
  }

  function installKeyboardInsetHandler() {
    updateKeyboardInset();
    if (window.visualViewport) {
      window.visualViewport.addEventListener('resize', scheduleKeyboardInsetUpdate);
      window.visualViewport.addEventListener('scroll', scheduleKeyboardInsetUpdate);
    }
    document.addEventListener('focusin', function () {
      window.setTimeout(scheduleKeyboardInsetUpdate, 80);
      window.setTimeout(scheduleKeyboardInsetUpdate, 280);
    }, true);
    document.addEventListener('focusout', function () {
      window.setTimeout(scheduleKeyboardInsetUpdate, 80);
      window.setTimeout(scheduleKeyboardInsetUpdate, 280);
    }, true);
  }

  function applyFontSize(fontSize) {
    var next = Math.round(clamp(fontSize, FONT_MIN, FONT_MAX));
    window.localStorage.setItem(FONT_KEY, String(next));
    updateFontLabel(next);
    applyFontToTerminal(next);
    scheduleTerminalResize();
  }

  function adjustFontSize(delta) {
    applyFontSize(readFontSize() + delta);
  }

  function resetFontSize() {
    applyFontSize(FONT_DEFAULT);
  }

  function findViewport() {
    return document.querySelector('.xterm-viewport');
  }

  function getActiveBuffer() {
    return termRef && termRef.buffer ? termRef.buffer.active : null;
  }

  function getCurrentScrollLine() {
    var buffer = getActiveBuffer();
    if (!buffer || typeof buffer.viewportY !== 'number') { return null; }
    return buffer.viewportY;
  }

  function getMaxScrollLine() {
    var buffer = getActiveBuffer();
    if (!buffer) { return null; }
    if (typeof buffer.baseY === 'number') { return buffer.baseY; }
    if (typeof buffer.length === 'number') {
      return Math.max(0, buffer.length - (termRef && termRef.rows ? termRef.rows : 0));
    }
    return null;
  }

  function getPageRows(viewport) {
    if (termRef && typeof termRef.rows === 'number' && termRef.rows > 0) {
      return Math.max(1, termRef.rows - 2);
    }
    return Math.max(1, Math.floor((viewport ? viewport.clientHeight : window.innerHeight) / estimateLineHeight(viewport)));
  }

  function estimateLineHeight(viewport) {
    var rows = termRef && typeof termRef.rows === 'number' && termRef.rows > 0 ? termRef.rows : 24;
    if (!viewport) { return Math.max(12, window.innerHeight / rows); }
    var buffer = getActiveBuffer();
    var totalRows = buffer && typeof buffer.baseY === 'number' ? buffer.baseY + rows : 0;
    if (totalRows > 0 && viewport.scrollHeight > viewport.clientHeight) {
      return Math.max(8, viewport.scrollHeight / totalRows);
    }
    return Math.max(8, viewport.clientHeight / rows);
  }

  function setViewportScrollTop(viewport, scrollTop) {
    if (!viewport) { return; }
    viewport.scrollTop = clamp(scrollTop, 0, Math.max(0, viewport.scrollHeight - viewport.clientHeight));
    if (typeof Event === 'function') {
      viewport.dispatchEvent(new Event('scroll'));
    }
  }

  function syncViewportToLine(viewport, line) {
    if (!viewport) { return; }
    window.requestAnimationFrame(function () {
      setViewportScrollTop(viewport, line * estimateLineHeight(viewport));
    });
  }

  function scrollToTerminalLine(line) {
    var viewport = findViewport();
    var maxLine = getMaxScrollLine();
    var currentLine = getCurrentScrollLine();
    if (maxLine === null) { return false; }
    var nextLine = Math.round(clamp(line, 0, maxLine));
    if (termRef && typeof termRef.scrollToLine === 'function') {
      termRef.scrollToLine(nextLine);
      syncViewportToLine(viewport, nextLine);
      return true;
    }
    if (termRef && typeof termRef.scrollLines === 'function' && currentLine !== null) {
      termRef.scrollLines(nextLine - currentLine);
      syncViewportToLine(viewport, nextLine);
      return true;
    }
    return false;
  }

  function scrollTerminalPages(pageCount) {
    var viewport = findViewport();
    if (pageCount < 0) {
      pageTmuxCopyUp();
    } else if (pageCount > 0) {
      pageTmuxCopyDown();
    }
    var currentLine = getCurrentScrollLine();
    if (currentLine !== null && scrollToTerminalLine(currentLine + (pageCount * getPageRows(viewport)))) {
      return;
    }
    if (termRef && typeof termRef.scrollPages === 'function') {
      termRef.scrollPages(pageCount);
    }
    if (!viewport) { return; }
    window.requestAnimationFrame(function () {
      setViewportScrollTop(viewport, viewport.scrollTop + (viewport.clientHeight * pageCount));
    });
  }

  function scrollTerminalBottom() {
    var viewport = findViewport();
    bottomTmuxCopyMode();
    var maxLine = getMaxScrollLine();
    if (maxLine !== null && scrollToTerminalLine(maxLine)) {
      window.requestAnimationFrame(function () {
        setViewportScrollTop(viewport, viewport ? viewport.scrollHeight : 0);
      });
      return;
    }
    if (termRef && typeof termRef.scrollToBottom === 'function') {
      termRef.scrollToBottom();
    }
    if (!viewport) { return; }
    window.requestAnimationFrame(function () {
      setViewportScrollTop(viewport, viewport.scrollHeight);
    });
  }

  function eventElement(target) {
    if (!target) { return null; }
    if (target.nodeType === 1) { return target; }
    return target.parentElement || null;
  }

  function isPointInStage(clientX, clientY) {
    var stage = document.getElementById('pb-stage');
    if (!stage || typeof clientX !== 'number' || typeof clientY !== 'number') {
      return false;
    }
    var rect = stage.getBoundingClientRect();
    return clientX >= rect.left && clientX <= rect.right && clientY >= rect.top && clientY <= rect.bottom;
  }

  function isTerminalTouchTarget(target, clientX, clientY) {
    var element = eventElement(target);
    if (element) {
      if (element.closest('#pb-topbar,#pb-toolbar,#pb-clip-panel')) { return false; }
      if (element.closest(CONTROL_SELECTOR)) { return false; }
      if (element.closest('#pb-stage,#terminal-container,.xterm,.xterm-screen,.xterm-viewport')) {
        return true;
      }
    }
    return isPointInStage(clientX, clientY);
  }

  function isXtermMouseEventsActive() {
    if (document.querySelector('.xterm.enable-mouse-events')) {
      return true;
    }
    var modes = termRef && termRef.modes ? termRef.modes : null;
    return !!(modes && modes.mouseTrackingMode && modes.mouseTrackingMode !== 'none');
  }

  function beginTerminalTouchScroll(target, clientX, clientY, pointerId) {
    if (isXtermMouseEventsActive()) {
      touchScroll = null;
      return false;
    }
    if (!isTerminalTouchTarget(target, clientX, clientY)) {
      touchScroll = null;
      return false;
    }
    var viewport = findViewport();
    if (!viewport) { return false; }
    touchScroll = {
      pointerId: pointerId,
      startY: clientY,
      startTop: viewport.scrollTop,
      startLine: getCurrentScrollLine(),
      sentRows: 0,
      tmuxStarted: false
    };
    return true;
  }

  function moveTerminalTouchScroll(clientY, event) {
    if (!touchScroll) { return; }
    var viewport = findViewport();
    if (!viewport) { return; }
    var delta = touchScroll.startY - clientY;
    if (Math.abs(delta) < 4) { return; }
    event.preventDefault();
    event.stopPropagation();
    var lineHeight = estimateLineHeight(viewport);
    var touchRows = Math.trunc((clientY - touchScroll.startY) / lineHeight);
    var rowsToSend = touchRows - touchScroll.sentRows;
    if (Math.abs(rowsToSend) >= 1) {
      var command = rowsToSend > 0 ? 'scroll-up' : 'scroll-down';
      var rowCount = Math.abs(rowsToSend);
      if (!touchScroll.tmuxStarted) {
        scrollTerminalsViaApi(command, rowCount, true);
        tmuxCopyModeLikely = true;
        touchScroll.tmuxStarted = true;
        touchScroll.sentRows = touchRows;
      } else {
        scrollTerminalsViaApi(command, rowCount, false);
        touchScroll.sentRows = touchRows;
      }
    }
    if (touchScroll.startLine !== null) {
      scrollToTerminalLine(touchScroll.startLine + Math.round(delta / lineHeight));
    }
    setViewportScrollTop(viewport, touchScroll.startTop + delta);
  }

  function endTerminalTouchScroll(pointerId) {
    if (pointerId !== undefined && touchScroll && touchScroll.pointerId !== pointerId) {
      return;
    }
    touchScroll = null;
  }

  function installTerminalTouchScroll() {
    if (window.PointerEvent) {
      document.addEventListener('pointerdown', function (event) {
        if (event.pointerType === 'mouse' || !event.isPrimary) { return; }
        if (!beginTerminalTouchScroll(event.target, event.clientX, event.clientY, event.pointerId)) { return; }
        activeScrollPointerId = event.pointerId;
        if (event.target.setPointerCapture) {
          try { event.target.setPointerCapture(event.pointerId); } catch (e) {}
        }
      }, { passive: true, capture: true });

      document.addEventListener('pointermove', function (event) {
        if (event.pointerType === 'mouse' || event.pointerId !== activeScrollPointerId) { return; }
        moveTerminalTouchScroll(event.clientY, event);
      }, { passive: false, capture: true });

      document.addEventListener('pointerup', function (event) {
        if (event.pointerId !== activeScrollPointerId) { return; }
        activeScrollPointerId = null;
        endTerminalTouchScroll(event.pointerId);
      }, { passive: true, capture: true });

      document.addEventListener('pointercancel', function (event) {
        if (event.pointerId !== activeScrollPointerId) { return; }
        activeScrollPointerId = null;
        endTerminalTouchScroll(event.pointerId);
      }, { passive: true, capture: true });
    }

    document.addEventListener('touchstart', function (event) {
      if (activeScrollPointerId !== null) { return; }
      if (event.touches.length !== 1) {
        touchScroll = null;
        return;
      }
      beginTerminalTouchScroll(event.target, event.touches[0].clientX, event.touches[0].clientY, null);
    }, { passive: true, capture: true });

    document.addEventListener('touchmove', function (event) {
      if (activeScrollPointerId !== null) { return; }
      if (!touchScroll || event.touches.length !== 1) { return; }
      moveTerminalTouchScroll(event.touches[0].clientY, event);
    }, { passive: false, capture: true });

    document.addEventListener('touchend', function () {
      if (activeScrollPointerId !== null) { return; }
      endTerminalTouchScroll(null);
    }, { passive: true, capture: true });

    document.addEventListener('touchcancel', function () {
      if (activeScrollPointerId !== null) { return; }
      endTerminalTouchScroll(null);
    }, { passive: true, capture: true });
  }

  function scrollTerminalsViaApi(command, count, first) {
    var direction = command === 'scroll-down' ? 'down' : 'up';
    if (!window.fetch) { return; }
    fetch('/api/terminals/scroll', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        direction: direction,
        count: Math.max(1, Math.min(80, Math.round(count || 1))),
        first: !!first
      }),
      keepalive: true
    }).catch(function () {});
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

  function focusTerminal() {
    if (!termRef || typeof termRef.focus !== 'function') { return; }
    try { termRef.focus(); } catch (e) {}
  }

  function scheduleTerminalFocus() {
    focusTerminal();
    window.requestAnimationFrame(focusTerminal);
    window.setTimeout(focusTerminal, 80);
  }

  function killCurrentTmuxWindow() {
    // The prefix+& binding targets the window visible in this exact tmux client.
    sendTmux('&');
    window.setTimeout(function () { send('y'); }, 220);
  }

  function startTmuxCopyModeForTouch() {
    tmuxCopyModeLikely = true;
    sendTmux(KEY_PAGE_UP);
  }

  function sendTmuxCopyCommand(command, count) {
    var repeat = Math.max(1, Math.min(60, Math.round(count || 1)));
    var key = command === 'scroll-up' ? KEY_CTRL_UP
      : command === 'scroll-down' ? KEY_CTRL_DOWN
      : command === 'page-down' ? KEY_PAGE_DOWN
      : command === 'page-up' ? KEY_PAGE_UP
      : command === 'cancel' ? KEY_ESC
      : '';
    if (!key) { return; }
    for (var i = 0; i < repeat; i += 1) {
      setTimeout(function () { send(key); }, i * 18);
    }
  }

  function pageTmuxCopyUp() {
    tmuxCopyModeLikely = true;
    sendTmux(KEY_PAGE_UP);
  }

  function pageTmuxCopyDown() {
    tmuxCopyModeLikely = true;
    sendTmuxCopyCommand('page-down');
  }

  function bottomTmuxCopyMode() {
    tmuxCopyModeLikely = false;
    sendTmuxCopyCommand('cancel');
  }

  function resetKillConfirm() {
    if (killConfirmTimer !== null) {
      window.clearTimeout(killConfirmTimer);
      killConfirmTimer = null;
    }
    document.querySelectorAll('[data-kill].pb-confirm').forEach(function (button) {
      button.classList.remove('pb-confirm');
      button.setAttribute('aria-pressed', 'false');
    });
  }

  function confirmKillTerminal(button) {
    if (button.classList.contains('pb-confirm')) {
      resetKillConfirm();
      killCurrentTmuxWindow();
      return;
    }
    resetKillConfirm();
    button.classList.add('pb-confirm');
    button.setAttribute('aria-pressed', 'true');
    killConfirmTimer = window.setTimeout(resetKillConfirm, 3500);
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

  function setSelectButton(active) {
    var btn = document.getElementById('pb-sel-btn');
    if (btn) { btn.classList.toggle('pb-active', active); }
  }

  function getClipPanel() {
    return document.getElementById('pb-clip-panel');
  }

  function getClipTextArea() {
    return document.getElementById('pb-clip-text');
  }

  function collectBufferText() {
    var text = '';
    if (!termRef || !termRef.buffer || !termRef.buffer.active) {
      return collectDomText();
    }
    var buffer = termRef.buffer.active;
    var lines = [];
    var start = Math.max(0, buffer.length - 2000);
    for (var i = start; i < buffer.length; i += 1) {
      var line = buffer.getLine(i);
      if (line && typeof line.translateToString === 'function') {
        lines.push(line.translateToString(true));
      }
    }
    text = lines.join('\\n').replace(/[\\s\\n]+$/, '');
    return text || collectDomText();
  }

  function collectDomText() {
    var nodes = document.querySelectorAll('.xterm-accessibility-tree, .xterm-rows');
    var parts = [];
    nodes.forEach(function (node) {
      var text = node.textContent || '';
      if (text) { parts.push(text); }
    });
    return parts.join('\\n').replace(/[\\s\\n]+$/, '');
  }

  function openClipPanel(mode, text) {
    var panel = getClipPanel();
    var area = getClipTextArea();
    if (!panel || !area) { return; }
    var selectMode = mode === 'select';
    var title = document.getElementById('pb-clip-title');
    var help = document.getElementById('pb-clip-help');
    // Mobile Safari can refuse useful selection handles in readonly textareas.
    area.readOnly = false;
    area.value = text || '';
    area.placeholder = selectMode ? '' : 'Touch and hold here, then choose Paste';
    area.setAttribute('aria-label', selectMode ? 'Terminal text selection' : 'Text to paste into terminal');
    panel.classList.add('pb-open');
    panel.setAttribute('data-mode', selectMode ? 'select' : 'paste');
    panel.setAttribute('aria-hidden', 'false');
    if (title) { title.textContent = selectMode ? 'Select terminal text' : 'Paste into terminal'; }
    if (help) {
      help.textContent = selectMode
        ? 'Select the text you need, then tap copy.'
        : 'Use the browser paste action below, then tap send.';
    }
    document.body.classList.toggle('pb-sel-mode', selectMode);
    setSelectButton(selectMode);
    window.requestAnimationFrame(function () {
      if (selectMode) {
        area.scrollTop = 0;
        return;
      }
      try { area.focus({ preventScroll: true }); } catch (e) { area.focus(); }
    });
  }

  function closeClipPanel() {
    var panel = getClipPanel();
    var area = getClipTextArea();
    if (panel) {
      panel.classList.remove('pb-open');
      panel.removeAttribute('data-mode');
      panel.setAttribute('aria-hidden', 'true');
    }
    if (area) {
      area.value = '';
      area.placeholder = '';
      area.readOnly = false;
    }
    document.body.classList.remove('pb-sel-mode');
    setSelectButton(false);
  }

  function toggleSelMode() {
    if (document.body.classList.contains('pb-sel-mode')) {
      closeClipPanel();
      return;
    }
    var selected = (termRef && typeof termRef.getSelection === 'function')
      ? termRef.getSelection() : '';
    openClipPanel('select', selected || collectBufferText());
  }

  function selectedPanelText() {
    var area = getClipTextArea();
    if (!area) { return ''; }
    if (area.selectionStart !== area.selectionEnd) {
      return area.value.slice(area.selectionStart, area.selectionEnd);
    }
    return area.value;
  }

  function selectedTerminalText() {
    if (termRef && typeof termRef.getSelection === 'function') {
      var text = termRef.getSelection();
      if (text) { return text; }
    }
    var selection = window.getSelection ? String(window.getSelection()) : '';
    return selection || '';
  }

  function fallbackCopyText(text) {
    openClipPanel('select', text);
  }

  function copyText(text) {
    if (!text) { return; }
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text).catch(function () {
        fallbackCopyText(text);
      });
      return;
    }
    fallbackCopyText(text);
  }

  function copySelection() {
    var text = selectedTerminalText() || selectedPanelText();
    if (!text) {
      text = collectBufferText();
      if (text) {
        openClipPanel('select', text);
      }
    }
    copyText(text);
  }

  function openPastePanel() {
    openClipPanel('paste', '');
  }

  function pasteFromClipboard() {
    if (!navigator.clipboard || !navigator.clipboard.readText) {
      openPastePanel();
      return;
    }
    navigator.clipboard.readText().then(function (text) {
      if (text) {
        send(text);
        scheduleTerminalFocus();
      } else {
        openPastePanel();
      }
    }).catch(openPastePanel);
  }

  function sendClipText() {
    var area = getClipTextArea();
    if (!area || !area.value) { return; }
    send(area.value);
    closeClipPanel();
    scheduleTerminalFocus();
  }

  function handleControlClick(button) {
    var kill = button.getAttribute('data-kill');
    if (kill !== null) {
      confirmKillTerminal(button);
      return;
    }
    resetKillConfirm();

    var selMode = button.getAttribute('data-sel-mode');
    if (selMode !== null) {
      toggleSelMode();
      return;
    }

    var copySel = button.getAttribute('data-copy-sel');
    if (copySel !== null) {
      copySelection();
      return;
    }

    var paste = button.getAttribute('data-paste');
    if (paste !== null) {
      pasteFromClipboard();
      return;
    }

    var clipCopy = button.getAttribute('data-clip-copy');
    if (clipCopy !== null) {
      copyText(selectedPanelText());
      return;
    }

    var clipSend = button.getAttribute('data-clip-send');
    if (clipSend !== null) {
      sendClipText();
      return;
    }

    var clipClose = button.getAttribute('data-clip-close');
    if (clipClose !== null) {
      closeClipPanel();
      scheduleTerminalFocus();
      return;
    }

    var font = button.getAttribute('data-font');
    if (font !== null) {
      if (font === 'reset') {
        resetFontSize();
      } else {
        adjustFontSize(parseFloat(font || '0'));
      }
      return;
    }

    var page = button.getAttribute('data-page');
    if (page !== null) {
      if (page === 'bottom') {
        scrollTerminalBottom();
      } else {
        scrollTerminalPages(parseFloat(page || '0'));
      }
      return;
    }

    var raw = button.getAttribute('data-send');
    if (raw !== null) {
      if (raw === KEY_ESC) {
        tmuxCopyModeLikely = false;
      }
      send(raw);
      return;
    }

    var tmux = button.getAttribute('data-tmux');
    if (tmux !== null) {
      sendTmux(tmux);
    }
  }

  function normalizeWsUrl(url) {
    // Keep ttyd's chosen base path. Caddy owns stripping /term before proxying.
    return url;
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

  var CONTROL_SELECTOR = '[data-send],[data-tmux],[data-font],[data-page],[data-kill],[data-sel-mode],[data-copy-sel],[data-paste],[data-clip-copy],[data-clip-send],[data-clip-close]';

  function activateControl(event) {
    var button = event.target.closest(CONTROL_SELECTOR);
    if (!button) { return; }
    event.preventDefault();
    event.stopPropagation();
    handleControlClick(button);
  }

  function isPasteControl(button) {
    return button && button.getAttribute('data-paste') !== null;
  }

  function isClipboardPanelControl(button) {
    return button && button.closest('#pb-clip-panel') !== null;
  }

  function shouldPreserveTerminalFocus(button) {
    if (!button || isClipboardPanelControl(button) || isPasteControl(button)) { return false; }
    return button.getAttribute('data-sel-mode') === null;
  }

  document.addEventListener('pointerdown', function (event) {
    var button = event.target.closest(CONTROL_SELECTOR);
    if (!shouldPreserveTerminalFocus(button)) { return; }
    // Prevent toolbar buttons from taking focus away from xterm's hidden input.
    event.preventDefault();
  }, { passive: false, capture: true });

  document.addEventListener('pointerup', function (event) {
    if (event.pointerType === 'mouse') { return; }
    var button = event.target.closest(CONTROL_SELECTOR);
    // WebKit can reject async clipboard reads unless they start from click.
    if (!button || isPasteControl(button)) { return; }
    lastPointerControlAt = Date.now();
    activateControl(event);
    if (shouldPreserveTerminalFocus(button)) { scheduleTerminalFocus(); }
  }, true);

  document.addEventListener('click', function (event) {
    var button = event.target.closest(CONTROL_SELECTOR);
    if (!button) { return; }
    if (!isPasteControl(button) && Date.now() - lastPointerControlAt < 700) {
      event.preventDefault();
      event.stopPropagation();
      return;
    }
    activateControl(event);
    if (shouldPreserveTerminalFocus(button)) { scheduleTerminalFocus(); }
  });

  installTerminalTouchScroll();
  installKeyboardInsetHandler();

  // Pinch-to-zoom
  var _pinchDist0 = 0;
  var _pinchFont0 = FONT_DEFAULT;
  document.addEventListener('touchstart', function (e) {
    if (e.touches.length === 2) {
      _pinchDist0 = Math.hypot(
        e.touches[1].clientX - e.touches[0].clientX,
        e.touches[1].clientY - e.touches[0].clientY
      );
      _pinchFont0 = readFontSize();
    }
  }, { passive: true });
  document.addEventListener('touchmove', function (e) {
    if (e.touches.length !== 2 || _pinchDist0 === 0) { return; }
    var dist = Math.hypot(
      e.touches[1].clientX - e.touches[0].clientX,
      e.touches[1].clientY - e.touches[0].clientY
    );
    applyFontSize(_pinchFont0 * dist / _pinchDist0);
  }, { passive: true });
  document.addEventListener('touchend', function (e) {
    if (e.touches.length < 2) { _pinchDist0 = 0; }
  }, { passive: true });

  installTermWatcher();
  watchStage();
  applyFontSize(readFontSize());
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
    if re.search(r'<meta\s+name=["\']viewport["\'][^>]*>', html, re.IGNORECASE):
        return re.sub(
            r'<meta\s+name=["\']viewport["\'][^>]*>',
            VIEWPORT_META,
            html,
            count=1,
            flags=re.IGNORECASE,
        )
    if "<head>" not in html:
        raise RuntimeError("Expected <head> marker for viewport metadata")
    return html.replace("<head>", f"<head>{VIEWPORT_META}", 1)


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
