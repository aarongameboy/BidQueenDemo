#!/usr/bin/env python3
"""本地美术资源库服务：仅 127.0.0.1，静态页 + 可写 overrides.json。"""
from __future__ import annotations

import json
import os
import sys
from datetime import datetime, timezone
from http import HTTPStatus
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parent.parent
LIB_DIR = ROOT / "docs" / "asset-library"
OVERRIDES_PATH = LIB_DIR / "overrides.json"
HOST = "127.0.0.1"
PORT = 8765

API_EDIT_CAPABLE = "/api/edit-capable"
API_OVERRIDES = "/api/overrides"


def load_overrides() -> dict:
    if not OVERRIDES_PATH.exists():
        return {"version": 1, "updatedAt": None, "assets": {}, "tokens": {"brand": {}, "nav_icons": {}}}
    try:
        data = json.loads(OVERRIDES_PATH.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        data = {}
    data.setdefault("version", 1)
    data.setdefault("assets", {})
    data.setdefault("tokens", {})
    data["tokens"].setdefault("brand", {})
    data["tokens"].setdefault("nav_icons", {})
    return data


def save_overrides(data: dict) -> None:
    data["version"] = 1
    data["updatedAt"] = datetime.now(timezone.utc).isoformat()
    data.setdefault("assets", {})
    data.setdefault("tokens", {})
    data["tokens"].setdefault("brand", {})
    data["tokens"].setdefault("nav_icons", {})
    OVERRIDES_PATH.parent.mkdir(parents=True, exist_ok=True)
    OVERRIDES_PATH.write_text(
        json.dumps(data, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )


class AssetLibraryHandler(SimpleHTTPRequestHandler):
    """静态资源库 + 本地编辑 API。"""

    def __init__(self, request, client_address, server) -> None:
        super().__init__(request, client_address, server, directory=str(LIB_DIR))

    def _is_local_client(self) -> bool:
        host = self.client_address[0]
        return host in ("127.0.0.1", "::1", "localhost")

    def _json_response(self, payload: dict, status: int = HTTPStatus.OK) -> None:
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def _read_json_body(self) -> dict | None:
        length = int(self.headers.get("Content-Length", 0))
        if length <= 0:
            return None
        raw = self.rfile.read(length)
        try:
            return json.loads(raw.decode("utf-8"))
        except json.JSONDecodeError:
            return None

    def do_GET(self) -> None:
        path = urlparse(self.path).path
        if path == API_EDIT_CAPABLE:
            self._json_response({
                "editable": self._is_local_client(),
                "localOnly": True,
                "overridesPath": str(OVERRIDES_PATH.relative_to(ROOT)).replace("\\", "/"),
            })
            return
        if path == API_OVERRIDES:
            if not self._is_local_client():
                self._json_response({"error": "仅允许本机访问"}, HTTPStatus.FORBIDDEN)
                return
            self._json_response(load_overrides())
            return
        super().do_GET()

    def do_PUT(self) -> None:
        path = urlparse(self.path).path
        if path != API_OVERRIDES:
            self.send_error(HTTPStatus.NOT_FOUND)
            return
        if not self._is_local_client():
            self._json_response({"error": "仅允许本机访问"}, HTTPStatus.FORBIDDEN)
            return
        body = self._read_json_body()
        if body is None:
            self._json_response({"error": "无效 JSON"}, HTTPStatus.BAD_REQUEST)
            return
        try:
            save_overrides(body)
        except OSError as exc:
            self._json_response({"error": str(exc)}, HTTPStatus.INTERNAL_SERVER_ERROR)
            return
        self._json_response({"ok": True, "updatedAt": body.get("updatedAt")})

    def log_message(self, format: str, *args) -> None:
        if args and isinstance(args[0], str) and args[0].startswith("GET /api"):
            return
        super().log_message(format, *args)


def main() -> None:
    os.chdir(LIB_DIR)
    with ThreadingHTTPServer((HOST, PORT), AssetLibraryHandler) as httpd:
        print(f"BidKing Asset Library (local only)")
        print(f"  URL:      http://{HOST}:{PORT}/")
        print(f"  Root:     {LIB_DIR}")
        print(f"  Edits:    {OVERRIDES_PATH}")
        print(f"  绑定地址: {HOST}:{PORT}（外网无法访问）")
        print("Press Ctrl+C to stop.")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nStopped.")
            sys.exit(0)


if __name__ == "__main__":
    main()
