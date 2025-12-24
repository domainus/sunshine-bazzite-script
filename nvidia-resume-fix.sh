#!/usr/bin/env bash
set -euo pipefail

read -r -p "Output (e.g. DP-3): " OUTPUT
read -r -p "Mode (e.g. 2560x1440@165): " MODE

if [[ -z "${OUTPUT:-}" || -z "${MODE:-}" ]]; then
  echo "Output and Mode are required." >&2
  exit 1
fi

sudo tee /usr/local/bin/kde-wayland-fix-resume <<'EOF_SCRIPT'
#!/usr/bin/env bash
set -euo pipefail

OUTPUT="__OUTPUT__"
MODE="__MODE__"

SLEEP_SEC=2

log() { logger -t kde-wayland-fix-resume -- "$*"; }

# Find the active KDE Wayland session user
pick_user() {
  while read -r sid; do
    local type desktop state name
    type="$(loginctl show-session "$sid" -p Type --value || true)"
    desktop="$(loginctl show-session "$sid" -p Desktop --value || true)"
    state="$(loginctl show-session "$sid" -p State --value || true)"
    name="$(loginctl show-session "$sid" -p Name --value || true)"

    if [[ "$type" == "wayland" && "$desktop" == "KDE" && "$state" == "active" && -n "$name" ]]; then
      echo "$name"
      return 0
    fi
  done < <(loginctl list-sessions --no-legend | awk '{print $1}')
  return 1
}

USER_NAME="$(pick_user || true)"
if [[ -z "${USER_NAME:-}" ]]; then
  log "No active KDE Wayland session found; skipping."
  exit 0
fi

log "Active KDE Wayland user: $USER_NAME"
sleep "$SLEEP_SEC"

# Run the actual fix inside the user session (DBus + XDG_RUNTIME_DIR required)
sudo -u "$USER_NAME" bash -lc "
  set -euo pipefail
  export XDG_RUNTIME_DIR=/run/user/\$(id -u)
  export DBUS_SESSION_BUS_ADDRESS=unix:path=\$XDG_RUNTIME_DIR/bus

  # 1) Ask KWin to reconfigure (harmless, often helps)
  if command -v qdbus >/dev/null 2>&1; then
    qdbus org.kde.KWin /KWin org.kde.KWin.reconfigure >/dev/null 2>&1 || true
  fi

  # 2) Re-assert output enable + mode using KScreen
  if command -v kscreen-doctor >/dev/null 2>&1; then
    kscreen-doctor output.${OUTPUT}.enable >/dev/null 2>&1 || true
    kscreen-doctor output.${OUTPUT}.mode.${MODE} >/dev/null 2>&1 || true
  fi
" || log "User-session part failed (non-fatal)."

log "Done."
EOF_SCRIPT

escape_sed() { printf '%s' "$1" | sed -e 's/[\/&]/\\&/g'; }
OUTPUT_ESC="$(escape_sed "$OUTPUT")"
MODE_ESC="$(escape_sed "$MODE")"

sudo sed -i "s|__OUTPUT__|${OUTPUT_ESC}|g" /usr/local/bin/kde-wayland-fix-resume
sudo sed -i "s|__MODE__|${MODE_ESC}|g" /usr/local/bin/kde-wayland-fix-resume

sudo chmod +x /usr/local/bin/kde-wayland-fix-resume

sudo mkdir -p /etc/systemd/system/systemd-suspend.service.d
sudo tee /etc/systemd/system/systemd-suspend.service.d/override.conf <<'EOF_OVERRIDE'
[Service]
ExecStartPost=/usr/local/bin/kde-wayland-fix-resume
EOF_OVERRIDE

sudo systemctl daemon-reload
