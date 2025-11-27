#!/bin/bash

TIMER_FILE="/tmp/sunshine_sleep_timer.pid"

 # If a disconnect happens → start a 60 second sleep countdown
(
    sleep 60

    # Only suspend if the PID file still exists (meaning no connection cancelled it)
    if [[ -f "$TIMER_FILE" ]]; then
    echo "[Sunshine Sleep] 60 seconds passed. Suspending now."
    systemctl suspend
    fi
) &

# Save the background PID so we can cancel it later
echo $! > "$TIMER_FILE"
echo "[Sunshine Sleep] Starting 60 second sleep timer (PID: $(cat "$TIMER_FILE"))"
;;