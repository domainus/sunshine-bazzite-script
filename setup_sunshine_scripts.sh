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

if [[ $EUID -ne 0 ]]; then
  echo "Not running as root; skipping system-sleep hook install."
  echo "Re-run with sudo to install /usr/local/bin/force_display_wake.sh and /etc/systemd/system-sleep/99-force-display-wake."
else
  echo "Installing force_display_wake.sh to /usr/local/bin..."
  cp force_display_wake.sh /usr/local/bin/force_display_wake.sh
  chmod +x /usr/local/bin/force_display_wake.sh
  echo "Creating systemd sleep hook..."
  cat > /etc/systemd/system-sleep/99-force-display-wake <<'EOF'
#!/usr/bin/env bash
case "$1" in
  post)
    /usr/local/bin/force_display_wake.sh
    ;;
esac
EOF
  chmod +x /etc/systemd/system-sleep/99-force-display-wake
  echo "System sleep hook installed."
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
