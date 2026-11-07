#!/usr/bin/env python3
"""Local questionnaire server for the screenshot app design interview.

Serves index.html on 127.0.0.1 and accepts a POST /submit payload, writing it
to answers-round<N>.json in the same directory.
"""

import json
import os
import re
import sys
from datetime import datetime
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import unquote, urlparse

ROOT = os.path.dirname(os.path.abspath(__file__))
PORT = int(os.environ.get("PORT", "47921"))


def now_iso():
    return datetime.now().astimezone().isoformat(timespec="seconds")


class Handler(BaseHTTPRequestHandler):
    server_version = "GrillSite/1.0"
    sys_version = ""

    def log_message(self, fmt, *args):
        sys.stderr.write("[%s] %s\n" % (now_iso(), fmt % args))

    def _send(self, status, body, content_type="application/json; charset=utf-8"):
        if isinstance(body, str):
            body = body.encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        try:
            self.wfile.write(body)
        except (BrokenPipeError, ConnectionResetError):
            pass

    def _json(self, obj, status=200):
        self._send(status, json.dumps(obj, ensure_ascii=False))

    def do_GET(self):
        path = urlparse(self.path).path
        if path == "/healthz":
            self._json({"ok": True, "now": now_iso()})
            return
        if path in ("/", "/index.html"):
            name = "index.html"
        else:
            name = unquote(path.lstrip("/"))
            if not re.fullmatch(r"[A-Za-z0-9._-]+\.(html|css|js|png|svg)", name):
                self._json({"ok": False, "error": "not found"}, 404)
                return
        full = os.path.abspath(os.path.join(ROOT, name))
        if os.path.dirname(full) != ROOT or not os.path.isfile(full):
            self._json({"ok": False, "error": "not found"}, 404)
            return
        ctype = {
            ".html": "text/html; charset=utf-8",
            ".css": "text/css; charset=utf-8",
            ".js": "application/javascript; charset=utf-8",
            ".png": "image/png",
            ".svg": "image/svg+xml",
        }[os.path.splitext(full)[1].lower()]
        with open(full, "rb") as fh:
            self._send(200, fh.read(), ctype)

    def do_POST(self):
        if urlparse(self.path).path != "/submit":
            self._json({"ok": False, "error": "not found"}, 404)
            return
        try:
            length = int(self.headers.get("Content-Length") or 0)
            raw = self.rfile.read(length) if length else b""
            payload = json.loads(raw.decode("utf-8"))
        except Exception as exc:  # noqa: BLE001 - report anything malformed as 400
            self._json({"ok": False, "error": f"invalid payload: {exc}"}, 400)
            return
        try:
            rnd = int(payload.get("round", 1))
        except (TypeError, ValueError):
            self._json({"ok": False, "error": "round must be an integer"}, 400)
            return
        if not 1 <= rnd <= 99:
            self._json({"ok": False, "error": "round out of range"}, 400)
            return
        payload["receivedAt"] = now_iso()
        out = os.path.join(ROOT, f"answers-round{rnd}.json")
        with open(out, "w", encoding="utf-8") as fh:
            json.dump(payload, fh, ensure_ascii=False, indent=2)
            fh.write("\n")
        print(f"[{now_iso()}] saved {out}", flush=True)
        self._json({"ok": True, "file": out})


def main():
    server = ThreadingHTTPServer(("127.0.0.1", PORT), Handler)
    print(f"grill server: http://127.0.0.1:{PORT}", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
