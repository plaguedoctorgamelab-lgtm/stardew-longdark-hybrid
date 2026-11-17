"""Strange Ranger's tracker: bugs and feature requests, and the latest build.

A small web page served from this computer to the home network. Anyone on
the network can open it, add a bug or a feature request, set its priority,
version and status, and download the latest playtest zip.

Run:   python tools/tracker/server.py            (or start_tracker.bat)
Then:  open the address it prints, from any device on the network.

Uses only Python's standard library. The list is kept in
tracker_data/items.json at the project root (not in git), with a backup of
the previous copy beside it each time it changes.
"""

import json
import os
import re
import socket
import sys
import threading
import time
from datetime import datetime
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DATA_DIR = os.path.join(ROOT, "tracker_data")
DATA = os.path.join(DATA_DIR, "items.json")
ZIP = os.path.join(ROOT, "export", "StrangeRanger.zip")
BUILD_INFO = os.path.join(ROOT, "export", "build_info.json")
PAGE = os.path.join(os.path.dirname(__file__), "page.html")
PORT = int(os.environ.get("TRACKER_PORT", "8080"))

KINDS = ["bug", "feature"]
PRIORITIES = ["high", "medium", "low"]
STATUSES = ["open", "in progress", "fixed", "won't fix"]
FIELDS = {"title", "kind", "priority", "status", "version", "fixed_in", "notes", "who"}

_lock = threading.Lock()


def project_version():
    try:
        text = open(os.path.join(ROOT, "project.godot"), encoding="utf-8").read()
        m = re.search(r'config/version="([^"]+)"', text)
        return m.group(1) if m else ""
    except OSError:
        return ""


def load():
    if not os.path.exists(DATA):
        return {"next_id": 1, "items": []}
    with open(DATA, encoding="utf-8") as f:
        return json.load(f)


def save(d):
    os.makedirs(DATA_DIR, exist_ok=True)
    if os.path.exists(DATA):
        os.replace(DATA, DATA + ".bak")
    tmp = DATA + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(d, f, indent=1, ensure_ascii=False)
    os.replace(tmp, DATA)


def clean(fields, base=None):
    """Keeps only known fields, trimmed, with choices held to their lists."""
    out = dict(base or {})
    for k, v in fields.items():
        if k not in FIELDS:
            continue
        v = str(v).strip()[:4000]
        if k == "kind" and v not in KINDS:
            continue
        if k == "priority" and v not in PRIORITIES:
            continue
        if k == "status" and v not in STATUSES:
            continue
        out[k] = v
    return out


def build_info():
    """The latest zip: its version, when it was built, and its size."""
    if not os.path.exists(ZIP):
        return {"available": False}
    info = {"available": True, "size_mb": round(os.path.getsize(ZIP) / 1048576, 1),
            "built": datetime.fromtimestamp(os.path.getmtime(ZIP)).strftime("%d %b %Y, %H:%M"),
            "version": ""}
    try:
        with open(BUILD_INFO, encoding="utf-8") as f:
            info.update(json.load(f))
    except (OSError, ValueError):
        pass
    return info


def lan_address():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("10.255.255.255", 1))  # no packet is sent; this picks the network card
        return s.getsockname()[0]
    except OSError:
        return "127.0.0.1"
    finally:
        s.close()


class Handler(BaseHTTPRequestHandler):
    server_version = "Tracker/1"

    def log_message(self, fmt, *args):
        sys.stdout.write("%s  %s\n" % (time.strftime("%H:%M:%S"), fmt % args))

    def _send(self, code, body, ctype="application/json; charset=utf-8", extra=None):
        data = body if isinstance(body, bytes) else body.encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        for k, v in (extra or {}).items():
            self.send_header(k, v)
        self.end_headers()
        self.wfile.write(data)

    def _json(self, code, obj):
        self._send(code, json.dumps(obj, ensure_ascii=False))

    def _body(self):
        n = int(self.headers.get("Content-Length") or 0)
        if n > 100000:
            raise ValueError("too large")
        return json.loads(self.rfile.read(n) or b"{}")

    def do_GET(self):
        path = urlparse(self.path).path
        if path in ("/", "/index.html"):
            self._send(200, open(PAGE, encoding="utf-8").read(), "text/html; charset=utf-8")
        elif path == "/api/items":
            with _lock:
                d = load()
            self._json(200, {"items": d["items"], "version": project_version(), "build": build_info(),
                             "choices": {"kind": KINDS, "priority": PRIORITIES, "status": STATUSES}})
        elif path == "/download":
            if not os.path.exists(ZIP):
                self._send(404, "No build yet.", "text/plain")
                return
            v = build_info().get("version") or project_version()
            name = "StrangeRanger-%s.zip" % v if v else "StrangeRanger.zip"
            self.send_response(200)
            self.send_header("Content-Type", "application/zip")
            self.send_header("Content-Length", str(os.path.getsize(ZIP)))
            self.send_header("Content-Disposition", 'attachment; filename="%s"' % name)
            self.end_headers()
            with open(ZIP, "rb") as f:
                while True:
                    chunk = f.read(1 << 20)
                    if not chunk:
                        break
                    self.wfile.write(chunk)
        else:
            self._send(404, "Not found", "text/plain")

    def do_POST(self):
        if urlparse(self.path).path != "/api/items":
            self._send(404, "Not found", "text/plain")
            return
        try:
            fields = self._body()
        except ValueError:
            self._json(400, {"error": "bad request"})
            return
        item = clean(fields, {"kind": "bug", "priority": "medium", "status": "open",
                              "version": project_version(), "fixed_in": "", "notes": "", "who": ""})
        if not item.get("title"):
            self._json(400, {"error": "a title is needed"})
            return
        with _lock:
            d = load()
            now = datetime.now().strftime("%Y-%m-%d %H:%M")
            item.update({"id": d["next_id"], "created": now, "updated": now})
            d["next_id"] += 1
            d["items"].append(item)
            save(d)
        self._json(200, item)

    def do_PUT(self):
        m = re.fullmatch(r"/api/items/(\d+)", urlparse(self.path).path)
        if not m:
            self._send(404, "Not found", "text/plain")
            return
        try:
            fields = self._body()
        except ValueError:
            self._json(400, {"error": "bad request"})
            return
        with _lock:
            d = load()
            for i, it in enumerate(d["items"]):
                if it["id"] == int(m.group(1)):
                    new = clean(fields, it)
                    if not new.get("title"):
                        self._json(400, {"error": "a title is needed"})
                        return
                    new["updated"] = datetime.now().strftime("%Y-%m-%d %H:%M")
                    d["items"][i] = new
                    save(d)
                    self._json(200, new)
                    return
        self._json(404, {"error": "no such item"})

    def do_DELETE(self):
        m = re.fullmatch(r"/api/items/(\d+)", urlparse(self.path).path)
        if not m:
            self._send(404, "Not found", "text/plain")
            return
        with _lock:
            d = load()
            before = len(d["items"])
            d["items"] = [it for it in d["items"] if it["id"] != int(m.group(1))]
            if len(d["items"]) == before:
                self._json(404, {"error": "no such item"})
                return
            save(d)
        self._json(200, {"ok": True})


def main():
    srv = ThreadingHTTPServer(("0.0.0.0", PORT), Handler)
    sys.stdout.reconfigure(line_buffering=True)
    print("Strange Ranger tracker")
    print("  on this computer:  http://localhost:%d" % PORT)
    print("  on the network:    http://%s:%d" % (lan_address(), PORT))
    print("  list kept in:      %s" % DATA)
    print("Ctrl+C to stop.")
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
