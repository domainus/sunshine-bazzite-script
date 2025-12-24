#!/usr/bin/env bash
set -euo pipefail

# Track the timer pid in a per-user location so no sudo is needed.
TIMER_FILE="${XDG_RUNTIME_DIR:-/tmp}/sunshine_sleep_timer.pid"

# If a disconnect happens → start a 60 second sleep countdown
(
    sleep 60

    # Only suspend if the PID file still exists (meaning no connection cancelled it)
    if [[ -f "$TIMER_FILE" ]]; then
        echo "[Sunshine Sleep] 60 seconds passed. Suspending now."
        if alias kde-sleep >/dev/null 2>&1; then
            kde-sleep
        elif command -v qdbus >/dev/null 2>&1; then
            qdbus org.kde.kglobalaccel /component/org_kde_powerdevil invokeShortcut "Sleep"
        else
            echo "[Sunshine Sleep] kde-sleep alias not found and qdbus missing." >&2
            exit 1
        fi
    fi
) &

# Save the background PID so we can cancel it later
echo $! > "$TIMER_FILE"
echo "[Sunshine Sleep] Starting 60 second sleep timer (PID: $(cat "$TIMER_FILE"))"
