#!/usr/bin/env bash
# Serves build/web/ at http://localhost:8060/ until Ctrl-C. PORT=... to change the port.
cd "$(dirname "$0")/../build/web" 2>/dev/null || { echo "no build/web, run tools/export_web.sh first"; exit 1; }
PORT=${PORT:-8060}
echo "http://localhost:$PORT/"
exec python3 -m http.server "$PORT" --bind 127.0.0.1
