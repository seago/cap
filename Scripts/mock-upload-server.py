#!/usr/bin/env python3
"""本地上传端点（#31 验收 / 手动测试用）。

- 接收 POST /upload 的 multipart 文件字段，保存到 --dir 目录；
- 返回 JSON {"url": "http://<host>:<port>/uploads/<name>"}（可用 --response-key 改字段名）；
- GET /uploads/<name> 返回已上传文件。

用法：
    python3 Scripts/mock-upload-server.py --port 8765 --dir /tmp/cap-uploads
然后：
    defaults write dev.bruce.cap uploadEndpoint "http://127.0.0.1:8765/upload"
"""

import argparse
import hashlib
import html
import http.server
import json
import os
import re
import threading
import uuid


def parse_boundary(content_type: str):
    match = re.search(r"boundary=([^;]+)", content_type or "")
    return match.group(1).strip().strip('"') if match else None


def parse_multipart(body: bytes, boundary: str):
    """返回 [(field_name, filename, data)]；够测试用，不追求完整 RFC。"""
    delimiter = ("--" + boundary).encode()
    parts = body.split(delimiter)
    results = []
    for part in parts:
        if not part or part in (b"--\r\n", b"--", b"\r\n"):
            continue
        part = part.lstrip(b"\r\n")
        if part.startswith(b"--"):
            continue
        header_blob, _, data = part.partition(b"\r\n\r\n")
        if not data:
            continue
        data = data.rstrip(b"\r\n")
        headers = header_blob.decode("utf-8", "replace")
        name_match = re.search(r'name="([^"]*)"', headers)
        filename_match = re.search(r'filename="([^"]*)"', headers)
        results.append((name_match.group(1) if name_match else "", filename_match.group(1) if filename_match else None, data))
    return results


class Handler(http.server.BaseHTTPRequestHandler):
    server_version = "CapMockUpload/1.0"
    upload_dir = "/tmp/cap-uploads"
    response_key = "url"

    def log_message(self, fmt, *args):
        print("[mock-upload] " + (fmt % args), flush=True)

    def _send_json(self, status: int, payload: dict):
        body = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self):
        if self.path not in ("/upload", "/", "/api/upload"):
            self._send_json(404, {"error": "not found"})
            return
        length = int(self.headers.get("Content-Length", "0"))
        body = self.rfile.read(length)
        boundary = parse_boundary(self.headers.get("Content-Type", ""))
        if not boundary:
            self._send_json(400, {"error": "missing multipart boundary"})
            return
        parts = parse_multipart(body, boundary)
        file_part = next(((name, filename, data) for name, filename, data in parts if filename), None)
        if not file_part:
            self._send_json(400, {"error": "no file field"})
            return
        _, filename, data = file_part
        suffix = os.path.splitext(filename or "upload")[1] or ".png"
        stored_name = f"{uuid.uuid4().hex[:12]}{suffix}"
        os.makedirs(self.upload_dir, exist_ok=True)
        with open(os.path.join(self.upload_dir, stored_name), "wb") as handle:
            handle.write(data)
        digest = hashlib.sha256(data).hexdigest()[:12]
        host = self.headers.get("Host", f"127.0.0.1:{self.server.server_port}")
        url = f"http://{host}/uploads/{stored_name}"
        print(f"[mock-upload] stored {stored_name} ({len(data)} bytes, sha256={digest})", flush=True)
        self._send_json(200, {self.response_key: url, "size": len(data), "sha256": digest})

    def do_GET(self):
        if not self.path.startswith("/uploads/"):
            self._send_json(404, {"error": "not found"})
            return
        name = os.path.basename(self.path)
        path = os.path.join(self.upload_dir, name)
        if not os.path.isfile(path):
            self._send_json(404, {"error": "not found"})
            return
        with open(path, "rb") as handle:
            data = handle.read()
        self.send_response(200)
        content_type = "image/png" if name.endswith(".png") else "application/octet-stream"
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--dir", default="/tmp/cap-uploads")
    parser.add_argument("--response-key", default="url")
    args = parser.parse_args()

    Handler.upload_dir = args.dir
    Handler.response_key = args.response_key
    server = http.server.ThreadingHTTPServer((args.host, args.port), Handler)
    print(f"[mock-upload] listening on http://{args.host}:{args.port}/upload, dir={args.dir}", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
