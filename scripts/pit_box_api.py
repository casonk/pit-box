#!/usr/bin/env python3
"""
Minimal HTTP API for pit-box web terminal window management.
Runs on loopback only; Caddy proxies /api/* from the mTLS VPN endpoint.

Endpoints:
  GET    /api/windows        — list active tmux windows (JSON)
  DELETE /api/windows/<n>    — kill tmux window N
"""
import argparse, json, subprocess, http.server

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
