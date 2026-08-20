#!/usr/bin/env bash
# Build admin web in release mode with CanvasKit bundled locally
# (no gstatic CDN fetch -> fast load even with slow internet)
# and serve it on http://localhost:8080
set -e
cd "$(dirname "$0")/.."

echo "== Building release (local CanvasKit) =="
flutter build web --release --no-web-resources-cdn

echo
echo "== Serving on http://localhost:8080 (Ctrl+C to stop) =="
python3 -m http.server 8080 --directory build/web