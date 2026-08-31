#!/usr/bin/env bash
# Developer helper: start the EXISTING FastAPI backend, then run the macOS app.
# Reuses the backend startup command from the repo README (uvicorn on :8000).
#
# Usage:
#   ./dev-macos.sh            # start backend (if not running) + run app
#   ./dev-macos.sh backend    # start backend only
#   ./dev-macos.sh app        # run macOS app only (assumes backend running)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BACKEND_DIR="$REPO_ROOT/backend"
MACOS_DIR="$REPO_ROOT/macos"

start_backend() {
  echo "▶ Starting FastAPI backend on http://localhost:8000 …"
  cd "$BACKEND_DIR"
  if [ -d venv ]; then source venv/bin/activate; fi
  uvicorn app.main:app --reload --port 8000
}

run_app() {
  echo "▶ Building & running macOS app (SwiftPM) …"
  cd "$MACOS_DIR"
  swift run InterviewPracticeListener
}

case "${1:-all}" in
  backend) start_backend ;;
  app) run_app ;;
  all)
    if curl -s http://localhost:8000/ >/dev/null 2>&1; then
      echo "✓ Backend already running."
    else
      echo "⚠ Backend not detected. Start it in another terminal:"
      echo "    cd backend && uvicorn app.main:app --reload --port 8000"
    fi
    run_app
    ;;
  *) echo "Usage: $0 [backend|app|all]"; exit 1 ;;
esac
