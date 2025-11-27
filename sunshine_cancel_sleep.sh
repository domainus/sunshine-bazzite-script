#!/usr/bin/env bash
set -euo pipefail

TIMER_FILE="${XDG_RUNTIME_DIR:-/tmp}/sunshine_sleep_timer.pid"

# A client connected → cancel any pending sleep timer
if [[ -f "$TIMER_FILE" ]]; then
    pid="$(cat "$TIMER_FILE" 2>/dev/null || true)"
    if [[ -n "${pid:-}" ]] && kill -0 "$pid" 2>/dev/null; then
        kill "$pid" 2>/dev/null || true
    fi

    rm -f "$TIMER_FILE"
    echo "[Sunshine Sleep] Cancelled pending sleep due to new connection"
fi
