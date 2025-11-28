#!/usr/bin/env bash

# ===== CONFIG =====
SERVICE_NAME="failsafe_displays"
SCRIPT_PATH="$HOME/.local/bin/sunshine_undo.sh"
SERVICE_PATH="$HOME/.config/systemd/user/${SERVICE_NAME}.service"

# ===== CREATE TARGET DIRECTORIES =====
mkdir -p "$HOME/.config/systemd/user"

# ===== CREATE THE SYSTEMD USER SERVICE =====
cat > "$SERVICE_PATH" << EOF
[Unit]
Description=A Fail Safe Display Reset incase Sunshine fails improperly

[Service]
Type=simple
ExecStart=$SCRIPT_PATH

[Install]
WantedBy=default.target
EOF


# ===== ENABLE & START SERVICE =====
systemctl --user daemon-reload
systemctl --user enable --now "$SERVICE_NAME.service"

echo "=============================================="
echo "User startup service installed and running!"
echo "Script:  $SCRIPT_PATH"
echo "Service: $SERVICE_PATH"
echo "=============================================="
