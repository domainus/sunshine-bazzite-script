#!/usr/bin/env bash
set -euo pipefail

# Track the timer pid in a per-user location so no sudo is needed.
TIMER_FILE="${XDG_RUNTIME_DIR:-/tmp}/sunshine_sleep_timer.pid"

suspend_system() {
    if command -v loginctl >/dev/null 2>&1; then
        loginctl suspend
    elif command -v systemctl >/dev/null 2>&1; then
        systemctl suspend
    else
        echo "[Sunshine Sleep] No suspend command available." >&2
        return 1
    fi
}

# If a disconnect happens → start a 60 second sleep countdown
(
    sleep 60

    # Only suspend if the PID file still exists (meaning no connection cancelled it)
    if [[ -f "$TIMER_FILE" ]]; then
        echo "[Sunshine Sleep] 60 seconds passed. Suspending now."
        suspend_system
    fi
) &

# Save the background PID so we can cancel it later
echo $! > "$TIMER_FILE"
echo "[Sunshine Sleep] Starting 60 second sleep timer (PID: $(cat "$TIMER_FILE"))"
