"""A stand-in for the Fortiva backend, for router/test/e2e.sh.

It answers the calls the router's agent makes, hands out the one door the
test runs, and keeps every event the router sends in /tmp/events.jsonl so
the test can read them. Standard library only, so it runs in a bare Python
image.

    python3 fake_api.py PORT DOOR_LINK
"""

import json
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

PORT = int(sys.argv[1])
LINK = sys.argv[2]
EVENTS = "/tmp/events.jsonl"
REGISTERS = "/tmp/registers.jsonl"

QUOTA = {
    "unlimited": False,
    "limit_bytes": 1 << 30,
    "used_bytes": 0,
    "remaining_bytes": 1 << 30,
    "blocked": False,
}


class Handler(BaseHTTPRequestHandler):
    def _body(self):
        n = int(self.headers.get("Content-Length") or 0)
        return json.loads(self.rfile.read(n) or b"{}") if n else {}

    def _send(self, obj, status=200):
        data = json.dumps(obj).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if self.path == "/api/v1/app/config":
            return self._send({"api_relays": []})
        return self._send({"detail": "not found"}, 404)

    def do_POST(self):
        body = self._body()
        platform = self.headers.get("X-App-Platform")
        if platform != "router":
            return self._send({"detail": f"platform {platform}"}, 400)
        if self.path == "/api/v1/devices/register":
            with open(REGISTERS, "a") as f:
                f.write(json.dumps(body) + "\n")
            return self._send({"ok": True})
        if self.path == "/api/v1/configs/dedicated":
            path = {
                "server_id": 1,
                "inbound_id": 1,
                "door": "tcp-none",
                "label": "Test server",
                "uri": LINK,
                "preferred": True,
            }
            return self._send({"configs": [LINK], "paths": [path], "quota": QUOTA})
        if self.path.endswith("/events"):
            with open(EVENTS, "a") as f:
                for e in body.get("events", []):
                    f.write(json.dumps({**e, "via_tunnel": body.get("via_tunnel")}) + "\n")
            return self._send({"accepted": len(body.get("events", []))})
        return self._send({"detail": "not found"}, 404)

    def log_message(self, fmt, *args):
        sys.stderr.write("api: " + (fmt % args) + "\n")


ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
