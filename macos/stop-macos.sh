#!/usr/bin/env bash
# Stops both parts of the application: the macOS app and the FastAPI backend.
#
# Usage:
#   ./stop-macos.sh            # stop app + backend
#   ./stop-macos.sh app        # stop only the macOS app
#   ./stop-macos.sh backend    # stop only the backend (port 8000)
set -uo pipefail

stop_app() {
  if pkill -f InterviewPracticeListener 2>/dev/null; then
    echo "✓ macOS app stopped."
  else
    echo "• macOS app was not running."
  fi
}

stop_backend() {
  local pids
  pids="$(lsof -nP -iTCP:8000 -sTCP:LISTEN -t 2>/dev/null || true)"
  if [ -n "$pids" ]; then
    echo "$pids" | xargs kill 2>/dev/null || true
    sleep 1
    echo "✓ Backend stopped (port 8000 freed)."
  else
    echo "• Backend was not running on port 8000."
  fi
}

case "${1:-all}" in
  app) stop_app ;;
  backend) stop_backend ;;
  all) stop_app; stop_backend ;;
  *) echo "Usage: $0 [app|backend|all]"; exit 1 ;;
esac
