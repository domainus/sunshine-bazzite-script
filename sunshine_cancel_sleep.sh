#!/bin/bash

TIMER_FILE="/tmp/sunshine_sleep_timer.pid"
 # A client connected → cancel any pending sleep timer
if [[ -f "$TIMER_FILE" ]]; then
    kill "$(cat "$TIMER_FILE")" 2>/dev/null
    rm -f "$TIMER_FILE"
    echo "[Sunshine Sleep] Cancelled pending sleep due to new connection"
fi
;;