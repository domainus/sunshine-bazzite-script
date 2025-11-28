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
for script in sunshine_do.sh sunshine_undo.sh sunshine_sleep.sh sunshine_cancel_sleep.sh; do
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
cp force_display_wake.sh ${TARGET_HOME}/.local/bin/
echo "force_display_wake.sh moved to ${TARGET_HOME}/.local/bin/."
sudo chmod +x ${TARGET_HOME}/.local/bin/force_display_wake.sh
echo "force_display_wake.sh marked executable."
mkdir -p "${TARGET_HOME}/.config/systemd/user"
echo "Creating wake_displays_from_sleep.service..."
cat > "${TARGET_HOME}/.config/systemd/user/wake_displays_from_sleep.service" <<'EOF'
[Unit]
Description=Force monitors to wake after resume

[Service]
Type=oneshot
ExecStart=%h/.local/bin/force_display_wake.sh

[Install]
WantedBy=systemd-user-sessions.service
WantedBy=graphical-session.target
WantedBy=gnome-session.target
WantedBy=plasma-session.target
WantedBy=suspend.target
EOF
echo "wake_displays_from_sleep.service written to ${TARGET_HOME}/.config/systemd/user/."

echo "Reloading user systemd units..."
systemctl --user daemon-reload
echo "Enabling wake_displays_from_sleep.service..."
systemctl --user enable wake_displays_from_sleep.service
echo "Display wake service enabled. Setup complete."
