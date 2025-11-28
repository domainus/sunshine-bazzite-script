#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="/etc/sddm.conf.d"
CONFIG_FILE="${CONFIG_DIR}/50-streamer-autologin.conf"
DISABLED_FILE="${CONFIG_FILE}.disabled"
LOGIN_UNIT="/etc/systemd/system/sunshine-streamer-login.service"
LOGOUT_UNIT="/etc/systemd/system/sunshine-streamer-logout.service"

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root (sudo) to write to system locations." >&2
  exit 1
fi

mkdir -p "$CONFIG_DIR"

# Write the SDDM autologin config and leave it disabled by default
cat > "$CONFIG_FILE" <<"CONF"
[Autologin]
User=streamer
Session=plasma
Relogin=true

[General]
DisplayServer=wayland
CONF

mv -f "$CONFIG_FILE" "$DISABLED_FILE"
echo "Autologin config staged at $DISABLED_FILE"

# Create systemd units that toggle autologin on Sunshine connect/disconnect
cat > "$LOGIN_UNIT" <<"SERVICE"
[Unit]
Description=Start streamer autologin when Sunshine client connects
After=sunshine.service

[Service]
Type=oneshot
ExecStart=/bin/bash -c "mv /etc/sddm.conf.d/50-streamer-autologin.conf.disabled /etc/sddm.conf.d/50-streamer-autologin.conf || true"
ExecStart=/usr/bin/chvt 1
ExecStart=/usr/bin/systemctl restart sddm.service

[Install]
WantedBy=sunshine-session@streamer.service
SERVICE

cat > "$LOGOUT_UNIT" <<"SERVICE"
[Unit]
Description=Lock streamer session and disable autologin when Sunshine disconnects
After=sunshine.service

[Service]
Type=oneshot
ExecStart=/usr/bin/loginctl lock-user streamer
ExecStart=/usr/bin/chvt 2
ExecStart=/bin/bash -c "mv /etc/sddm.conf.d/50-streamer-autologin.conf /etc/sddm.conf.d/50-streamer-autologin.conf.disabled || true"

[Install]
WantedBy=sunshine-disconnect@streamer.service
SERVICE

systemctl daemon-reload
systemctl enable sunshine-streamer-login.service
systemctl enable sunshine-streamer-logout.service

echo "Created and enabled sunshine-streamer-login.service and sunshine-streamer-logout.service."
