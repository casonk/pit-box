#!/usr/bin/env python3
"""
Minimal HTTP API for pit-box web terminal state and window management.
Runs on loopback only; Caddy proxies /api/* from the mTLS VPN endpoint.

Endpoints:
  GET    /api/state          - combined tmux windows + live browser terminals
  GET    /api/windows        - list tmux windows
  DELETE /api/windows/<n>    - kill tmux window N
"""
import argparse
import http.server
import json
import subprocess

DEFAULT_PORT    = 7682
DEFAULT_SESSION = "pit-box"

SESSION = DEFAULT_SESSION  # set in main()


def tmux(*args) -> subprocess.CompletedProcess:
    return subprocess.run(
        ["tmux", *args],
        capture_output=True, text=True,
    )


def list_windows():
    r = tmux("list-windows", "-t", SESSION,
             "-F", "#{window_index}\t#{window_name}\t#{window_active}")
    if r.returncode != 0:
        return []
    windows = []
    for line in r.stdout.strip().splitlines():
        idx, name, active = line.split("\t", 2)
        windows.append({"index": int(idx), "name": name, "active": active == "1"})
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


def kill_window(index: int) -> bool:
    r = tmux("kill-window", "-t", f"{SESSION}:{index}")
    return r.returncode == 0


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
        if self.path == "/api/windows":
            self._send(200, list_windows())
        else:
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
    global SESSION
    p = argparse.ArgumentParser()
    p.add_argument("--port",    type=int, default=DEFAULT_PORT)
    p.add_argument("--session", default=DEFAULT_SESSION)
    args = p.parse_args()
    SESSION = args.session

    server = http.server.HTTPServer(("127.0.0.1", args.port), Handler)
    print(f"pit-box API listening on 127.0.0.1:{args.port} (session={SESSION})")
    server.serve_forever()


if __name__ == "__main__":
    main()
