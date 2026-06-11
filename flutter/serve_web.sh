#!/usr/bin/env bash
#
# Build the Flutter web app with the laptop's current LAN IP baked in as the
# default backend URL, then serve build/web on the LAN over HTTP.
#
# Usage:
#   ./serve_web.sh            # build + serve on port 8080
#   PORT=9000 ./serve_web.sh  # custom port
#
# The backend must be running with --host 0.0.0.0 so other devices can reach it:
#   cd ../backend && uvicorn app.main:app --host 0.0.0.0
#
set -euo pipefail

cd "$(dirname "$0")"

PORT="${PORT:-8080}"
LAN_IP="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo 127.0.0.1)"
API_URL="http://${LAN_IP}:8000"

echo "LAN IP:       ${LAN_IP}"
echo "Backend URL:  ${API_URL} (baked in as default)"
echo "Building web app..."
flutter build web --release --dart-define=API_BASE_URL="${API_URL}"

echo ""
echo "Serving on:"
echo "  http://localhost:${PORT}      (this laptop)"
echo "  http://${LAN_IP}:${PORT}   (other devices on your network)"
echo ""
echo "Press Ctrl+C to stop."
cd build/web
exec python3 -m http.server "${PORT}" --bind 0.0.0.0
