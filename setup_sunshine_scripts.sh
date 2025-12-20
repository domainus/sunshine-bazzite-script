#!/usr/bin/env bash
set -euo pipefail

TARGET_USER="${SUDO_USER:-$USER}"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
DEST="${TARGET_HOME}/.local/bin"

echo "Target user: $TARGET_USER ($TARGET_HOME)"
echo "Ensuring destination exists: $DEST"
mkdir -p "$DEST"
echo "Destination ready."

echo "Verifying and copying Sunshine scripts..."
for script in sunshine_do.sh sunshine_undo.sh sunshine_sleep.sh sunshine_cancel_sleep.sh fix_displays.sh; do
  if [ ! -f "$script" ]; then
    echo "Error: $script not found in current directory. Aborting."
    exit 1
  fi

  echo "Copying $script to $DEST"
  cp "$script" "$DEST/"

  echo "Making $DEST/$script executable"
  chmod +x "$DEST/$script"
done
echo "All Sunshine scripts copied and marked executable."

echo "Done. Scripts installed to $DEST"

CONFIG_DIR="${TARGET_HOME}/.config/sunshine"
CONFIG="${CONFIG_DIR}/sunshine.conf"
echo "Writing global_prep_cmd to $CONFIG"
mkdir -p "$CONFIG_DIR"
cat > "$CONFIG" <<'EOF'
global_prep_cmd = [{"do":"bash -c \"${HOME}/.local/bin/sunshine_do.sh \\\"${SUNSHINE_CLIENT_WIDTH}\\\" \\\"${SUNSHINE_CLIENT_HEIGHT}\\\" \\\"${SUNSHINE_CLIENT_FPS}\\\" \\\"${SUNSHINE_CLIENT_HDR}\\\"\"","undo":"bash -c \"${HOME}/.local/bin/sunshine_undo.sh\""}]
EOF
echo "sunshine.conf written."

echo "Applying display wake from sleep fix...."
cp force_display_wake.sh "${TARGET_HOME}/.local/bin/"
echo "force_display_wake.sh moved to ${TARGET_HOME}/.local/bin/."
chmod +x "${TARGET_HOME}/.local/bin/force_display_wake.sh"
echo "force_display_wake.sh marked executable."

USER_SYSTEMD_DIR="${TARGET_HOME}/.config/systemd/user"
WAKE_UNIT="${USER_SYSTEMD_DIR}/wake_displays_from_sleep.service"

echo "Creating user resume hook at ${WAKE_UNIT}..."
mkdir -p "${USER_SYSTEMD_DIR}"
cat > "${WAKE_UNIT}" <<'EOF'
[Unit]
Description=Wake displays after resume
After=suspend.target

[Service]
Type=oneshot
ExecStart=%h/.local/bin/force_display_wake.sh

[Install]
WantedBy=suspend.target
EOF

echo "Enabling user resume hook..."
if [[ $EUID -eq 0 ]]; then
  sudo -u "${TARGET_USER}" systemctl --user daemon-reload
  sudo -u "${TARGET_USER}" systemctl --user enable --now wake_displays_from_sleep.service || true
else
  systemctl --user daemon-reload
  systemctl --user enable --now wake_displays_from_sleep.service || true
fi

unlock_script="$DEST/unlock_on_connect.sh"

echo "Creating unlock script at $unlock_script..."
cat >"$unlock_script" <<'EOF'
#!/usr/bin/env bash
sleep 3
# Unlocks the session for user ryan when Sunshine client connects
SESSION_ID="$(loginctl list-sessions --no-legend --no-pager | awk '$3=="ryan" {print $1; exit}')"
if [ -z "$SESSION_ID" ]; then
  echo "No active session found for user ryan" >&2
  exit 1
fi
/usr/bin/loginctl unlock-session "$SESSION_ID"
EOF
chmod +x "$unlock_script"

echo "Unlock script enabled. Setup complete."
