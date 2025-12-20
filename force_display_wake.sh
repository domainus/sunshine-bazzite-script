#!/usr/bin/env bash
set -euo pipefail

log() { echo "[force_display_wake] $*"; }

# Give NVIDIA + compositor a moment after resume
sleep 2

# Force all DP/HDMI connectors ON, then return to DETECT.
# This is more reliable than kscreen-doctor on buggy resume paths.
shopt -s nullglob
connectors=(/sys/class/drm/card*-DP-*/force /sys/class/drm/card*-HDMI-*/force)

if ((${#connectors[@]} == 0)); then
  log "No DRM connector force files found under /sys/class/drm. Exiting."
  exit 0
fi

log "Forcing connectors ON..."
for f in "${connectors[@]}"; do
  echo on > "$f" 2>/dev/null || true
done

sleep 1

log "Returning connectors to DETECT..."
for f in "${connectors[@]}"; do
  echo detect > "$f" 2>/dev/null || true
done

# Trigger DRM udev events (harmless, sometimes helps)
udevadm trigger --subsystem-match=drm >/dev/null 2>&1 || true

# Last resort: VT flip forces a modeset on many NVIDIA systems.
if command -v chvt >/dev/null 2>&1; then
  log "VT flip (1 -> 2 -> 1) ..."
  chvt 1 2>/dev/null || true
  sleep 0.2
  chvt 2 2>/dev/null || true
  sleep 0.2
  chvt 1 2>/dev/null || true
fi

log "Done."
