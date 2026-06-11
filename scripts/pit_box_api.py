#!/usr/bin/env python3
"""
Minimal HTTP API for pit-box web terminal state and window management.
Runs on loopback only; Caddy proxies /api/* from the mTLS VPN endpoint.

Endpoints:
  GET    /api/state            - combined tmux windows + live browser terminals
  GET    /api/windows          - list tmux windows
  POST   /api/terminals/scroll - scroll attached WebTerm tmux copy-mode panes
  POST   /api/rebuild          - run rebuild_webservices.sh via sudo -S (password in body)
  POST   /api/promote          - render prod configs then rebuild all prod services (one password)
  POST   /api/task             - run a no-sudo pit-box script (task name in body)
  DELETE /api/windows/<n>      - kill tmux window N
"""
import argparse
import http.server
import json
import os
import subprocess

DEFAULT_PORT           = 7682
DEFAULT_SESSION        = "pit-box"
DEFAULT_REBUILD_SCRIPT = ""
DEFAULT_SETTINGS_FILE  = ""
DEFAULT_ENV_LABEL      = ""
DEFAULT_SIBLING_URL    = ""
DEFAULT_COCKPIT_URL    = ""
DEFAULT_DESKTOP_URL    = ""

SESSION        = DEFAULT_SESSION         # set in main()
REBUILD_SCRIPT = DEFAULT_REBUILD_SCRIPT  # set in main()
SETTINGS_FILE  = DEFAULT_SETTINGS_FILE   # set in main()
ENV_LABEL      = DEFAULT_ENV_LABEL       # set in main()
SIBLING_URL    = DEFAULT_SIBLING_URL     # set in main()
COCKPIT_URL    = DEFAULT_COCKPIT_URL     # set in main()
DESKTOP_URL    = DEFAULT_DESKTOP_URL     # set in main()


def tmux(*args) -> subprocess.CompletedProcess:
    return subprocess.run(
        ["tmux", *args],
        capture_output=True, text=True,
    )


def list_windows():
    r = tmux(
        "list-windows", "-t", SESSION, "-F",
        "#{window_index}\t#{window_name}\t#{window_active}"
        "\t#{pane_current_command}\t#{window_bell_flag}\t#{pane_dead}",
    )
    if r.returncode != 0:
        return []
    windows = []
    for line in r.stdout.strip().splitlines():
        idx, name, active, cmd, bell, dead = line.split("\t", 5)
        windows.append({
            "index": int(idx),
            "name":   name,
            "active": active == "1",
            "cmd":    cmd,
            "bell":   bell == "1",
            "dead":   dead == "1",
        })
    return windows


def list_terminals():
    result = tmux(
        "list-sessions",
        "-F",
        "#{session_name}\t#{session_attached}\t#{session_group}\t#{window_index}\t#{window_name}",
    )
    if result.returncode != 0:
        return []

    terminals = []
    for line in result.stdout.strip().splitlines():
        if not line:
            continue
        name, attached, group, window_index, window_name = line.split("\t", 4)
        attached_count = int(attached)
        if group != SESSION or not name.startswith("pb-") or attached_count < 1:
            continue
        terminals.append(
            {
                "name": name,
                "attached": attached_count,
                "group": group,
                "current_window": int(window_index),
                "current_name": window_name,
            }
        )
    terminals.sort(key=lambda item: item["name"])
    return terminals


def get_state():
    terminals = list_terminals()
    return {
        "windows": list_windows(),
        "terminals": terminals,
        "live_terminals": len(terminals),
    }


def get_env() -> dict:
    label = ENV_LABEL or ""
    if label == "prod":
        sibling_label = "dev"
    elif label == "dev":
        sibling_label = "prod"
    else:
        sibling_label = ""
    services = {k: v for k, v in [("cockpit", COCKPIT_URL), ("desktop", DESKTOP_URL)] if v}
    return {
        "label": label,
        "sibling_label": sibling_label,
        "sibling_url": SIBLING_URL or "",
        "services": services,
    }


def rebuild_service(service: str, password: str = "") -> dict:
    _ALLOWED = frozenset({"smart", "ttyd", "api", "dns", "caddy", "cockpit", "rdp", "desktop-web", "all", "activate"})
    if service not in _ALLOWED:
        return {"ok": False, "error": f"unknown service: {service!r}"}
    if not REBUILD_SCRIPT:
        return {"ok": False, "error": "rebuild script not configured (--rebuild-script)"}
    cmd = ["sudo", "-S", "--", REBUILD_SCRIPT]
    if SETTINGS_FILE:
        cmd += ["--settings", SETTINGS_FILE]
    if service != "all":
        cmd.append(service)
    try:
        r = subprocess.run(
            cmd,
            input=password + "\n",
            capture_output=True,
            text=True,
            timeout=120,
        )
    except subprocess.TimeoutExpired:
        return {"ok": False, "error": "rebuild timed out (120 s)"}
    except OSError as exc:
        return {"ok": False, "error": str(exc)}
    combined = "\n".join(filter(None, [r.stdout.strip(), r.stderr.strip()]))
    lines = combined.splitlines()
    return {"ok": r.returncode == 0, "output": "\n".join(lines[-30:])}


def kill_window(index: int) -> bool:
    r = tmux("kill-window", "-t", f"{SESSION}:{index}")
    return r.returncode == 0


_TASK_SCRIPTS: dict[str, str] = {
    "validate":       "validate.sh",
    "render-configs": "render_configs.sh",
    "package-client": "package_client.sh",
}


def promote_to_prod(password: str) -> dict:
    """Render prod configs (no sudo) then rebuild all prod services (one sudo call)."""
    if not REBUILD_SCRIPT:
        return {"ok": False, "error": "rebuild script not configured (--rebuild-script)"}
    scripts_dir = os.path.dirname(REBUILD_SCRIPT)
    render_script = os.path.join(scripts_dir, "render_configs.sh")
    try:
        r1 = subprocess.run([render_script], capture_output=True, text=True, timeout=60)
    except subprocess.TimeoutExpired:
        return {"ok": False, "error": "render timed out (60 s)"}
    except OSError as exc:
        return {"ok": False, "error": str(exc)}
    if r1.returncode != 0:
        combined = "\n".join(filter(None, [r1.stdout.strip(), r1.stderr.strip()]))
        lines = combined.splitlines()
        return {"ok": False, "error": "render_configs failed", "output": "\n".join(lines[-30:])}
    # Intentionally no --settings: targets prod settings.env regardless of current instance
    cmd = ["sudo", "-S", "--", REBUILD_SCRIPT]
    try:
        r2 = subprocess.run(
            cmd,
            input=password + "\n",
            capture_output=True,
            text=True,
            timeout=120,
        )
    except subprocess.TimeoutExpired:
        return {"ok": False, "error": "rebuild timed out (120 s)"}
    except OSError as exc:
        return {"ok": False, "error": str(exc)}
    render_out = "\n".join(filter(None, [r1.stdout.strip(), r1.stderr.strip()]))
    rebuild_out = "\n".join(filter(None, [r2.stdout.strip(), r2.stderr.strip()]))
    combined_out = "\n".join(filter(None, [render_out, rebuild_out]))
    lines = combined_out.splitlines()
    return {"ok": r2.returncode == 0, "output": "\n".join(lines[-30:])}


def run_task(task: str) -> dict:
    if task not in _TASK_SCRIPTS:
        return {"ok": False, "error": f"unknown task: {task!r}"}
    if not REBUILD_SCRIPT:
        return {"ok": False, "error": "scripts directory not configured (--rebuild-script)"}
    script = os.path.join(os.path.dirname(REBUILD_SCRIPT), _TASK_SCRIPTS[task])
    cmd = [script]
    if task == "render-configs" and SETTINGS_FILE:
        cmd += ["--settings", SETTINGS_FILE]
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
    except subprocess.TimeoutExpired:
        return {"ok": False, "error": "task timed out (60 s)"}
    except OSError as exc:
        return {"ok": False, "error": str(exc)}
    combined = "\n".join(filter(None, [r.stdout.strip(), r.stderr.strip()]))
    lines = combined.splitlines()
    return {"ok": r.returncode == 0, "output": "\n".join(lines[-30:])}


def pane_state(session_name: str) -> dict:
    target = f"{session_name}:"
    result = tmux(
        "display-message", "-p", "-t", target,
        "#{pane_current_command}\t#{pane_in_mode}",
    )
    if result.returncode != 0:
        return {"command": "", "in_mode": False}
    command, in_mode = (result.stdout.rstrip("\n").split("\t", 1) + ["0"])[:2]
    return {
        "command": command,
        "in_mode": in_mode == "1",
    }


def attached_terminal_names() -> list[str]:
    names = [item["name"] for item in list_terminals()]
    return names or [SESSION]


def scroll_foreground_app(session_name: str, direction: str, count: int) -> bool:
    target = f"{session_name}:"
    key = "C-Up" if direction == "up" else "C-Down"
    ok = True
    for _ in range(count):
        ok = tmux("send-keys", "-t", target, key).returncode == 0 and ok
    return ok


def scroll_terminal(session_name: str, direction: str, count: int, first: bool) -> bool:
    target = f"{session_name}:"
    state = pane_state(session_name)
    if state["command"] in {"codex", "node"} and not state["in_mode"]:
        return scroll_foreground_app(session_name, direction, count)

    ok = True
    if first or not state["in_mode"]:
        # Enter copy-mode without sending any key sequence to the foreground app.
        ok = tmux("copy-mode", "-t", target).returncode == 0
    command = "scroll-up" if direction == "up" else "scroll-down"
    if count > 0:
        ok = tmux("send-keys", "-t", target, "-X", "-N", str(count), command).returncode == 0 and ok
    return ok


def scroll_terminals(direction: str, count: int, first: bool) -> dict:
    count = max(1, min(80, count))
    names = attached_terminal_names()
    results = []
    for name in names:
        results.append({"name": name, "ok": scroll_terminal(name, direction, count, first)})
    return {
        "ok": all(item["ok"] for item in results),
        "terminals": results,
    }


class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass

    def _send(self, status: int, body: object):
        data = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if self.path == "/api/state":
            self._send(200, get_state())
            return
        if self.path == "/api/env":
            self._send(200, get_env())
            return
        if self.path == "/api/windows":
            self._send(200, list_windows())
        else:
            self._send(404, {"error": "not found"})

    def _read_json(self):
        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            return None
        if length <= 0 or length > 4096:
            return None
        try:
            return json.loads(self.rfile.read(length).decode())
        except (json.JSONDecodeError, UnicodeDecodeError):
            return None

    def do_POST(self):
        if self.path == "/api/terminals/scroll":
            payload = self._read_json()
            if not isinstance(payload, dict):
                self._send(400, {"error": "invalid json body"})
                return
            direction = str(payload.get("direction", "up"))
            if direction not in {"up", "down"}:
                self._send(400, {"error": "invalid direction"})
                return
            try:
                count = int(payload.get("count", 1))
            except (TypeError, ValueError):
                self._send(400, {"error": "invalid count"})
                return
            result = scroll_terminals(direction, count, bool(payload.get("first", False)))
            self._send(200 if result["ok"] else 500, result)
            return
        if self.path == "/api/rebuild":
            payload = self._read_json()
            if not isinstance(payload, dict):
                self._send(400, {"error": "invalid json body"})
                return
            service = str(payload.get("service", ""))
            password = str(payload.get("password", ""))
            result = rebuild_service(service, password)
            self._send(200, result)
            return
        if self.path == "/api/promote":
            payload = self._read_json()
            if not isinstance(payload, dict):
                self._send(400, {"error": "invalid json body"})
                return
            password = str(payload.get("password", ""))
            result = promote_to_prod(password)
            self._send(200, result)
            return
        if self.path == "/api/task":
            payload = self._read_json()
            if not isinstance(payload, dict):
                self._send(400, {"error": "invalid json body"})
                return
            task = str(payload.get("task", ""))
            result = run_task(task)
            self._send(200, result)
            return
        self._send(404, {"error": "not found"})

    def do_DELETE(self):
        if self.path.startswith("/api/windows/"):
            part = self.path.split("/")[-1]
            try:
                n = int(part)
            except ValueError:
                self._send(400, {"error": "invalid window index"})
                return
            if kill_window(n):
                self._send(200, {"ok": True})
            else:
                self._send(500, {"error": "kill-window failed"})
        else:
            self._send(404, {"error": "not found"})


def main():
    global SESSION, REBUILD_SCRIPT, SETTINGS_FILE
    global ENV_LABEL, SIBLING_URL, COCKPIT_URL, DESKTOP_URL
    p = argparse.ArgumentParser()
    p.add_argument("--port",           type=int, default=DEFAULT_PORT)
    p.add_argument("--session",        default=DEFAULT_SESSION)
    p.add_argument("--rebuild-script", default=DEFAULT_REBUILD_SCRIPT,
                   help="Absolute path to rebuild_webservices.sh")
    p.add_argument("--settings-file",  default=DEFAULT_SETTINGS_FILE,
                   help="Settings file passed to rebuild_webservices.sh (e.g. settings.dev.env)")
    p.add_argument("--env-label",      default=DEFAULT_ENV_LABEL,
                   help="Environment label shown in the homepage badge (e.g. prod or dev)")
    p.add_argument("--sibling-url",    default=DEFAULT_SIBLING_URL,
                   help="Homepage URL of the sibling environment for the env toggle")
    p.add_argument("--cockpit-url",    default=DEFAULT_COCKPIT_URL,
                   help="Full URL to the Cockpit web UI (shown on homepage if set)")
    p.add_argument("--desktop-url",    default=DEFAULT_DESKTOP_URL,
                   help="Full URL to the Guacamole desktop UI (shown on homepage if set)")
    args = p.parse_args()
    SESSION        = args.session
    REBUILD_SCRIPT = args.rebuild_script
    SETTINGS_FILE  = args.settings_file
    ENV_LABEL      = args.env_label
    SIBLING_URL    = args.sibling_url
    COCKPIT_URL    = args.cockpit_url
    DESKTOP_URL    = args.desktop_url

    server = http.server.HTTPServer(("127.0.0.1", args.port), Handler)
    print(f"pit-box API listening on 127.0.0.1:{args.port} (session={SESSION}, env={ENV_LABEL or 'unset'})")
    server.serve_forever()


if __name__ == "__main__":
    main()
