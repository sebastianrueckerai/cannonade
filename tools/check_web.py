#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["playwright"]
# ///
"""Smoke test of the browser build: serves build/web, opens it in headless Chromium, waits for the
engine, saves build/web-check.png and exits 1 on a page error. Usage: tools/check_web.py [seconds]"""

import http.server
import socketserver
import sys
import threading
from pathlib import Path

from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parent.parent
WEB = ROOT / "build" / "web"
PORT = 8061


class Quiet(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *args):
        pass


def serve():
    handler = lambda *a, **k: Quiet(*a, directory=str(WEB), **k)
    srv = socketserver.TCPServer(("127.0.0.1", PORT), handler)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    return srv


def main():
    if not (WEB / "index.html").exists():
        sys.exit("no build/web, run tools/export_web.sh first")
    wait = float(sys.argv[1]) if len(sys.argv) > 1 else 12.0
    srv = serve()
    errors = []
    with sync_playwright() as p:
        browser = p.chromium.launch(args=["--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader"])
        page = browser.new_page(viewport={"width": 1280, "height": 720})
        page.on("pageerror", lambda e: errors.append(str(e)))
        page.on("console", lambda m: errors.append(m.text) if m.type == "error" else None)
        page.goto(f"http://127.0.0.1:{PORT}/", wait_until="load")
        page.wait_for_timeout(wait * 1000)
        out = ROOT / "build" / "web-check.png"
        page.screenshot(path=str(out))
        browser.close()
    srv.shutdown()
    for e in errors:
        print("page error:", e[:300])
    print(out)
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()
