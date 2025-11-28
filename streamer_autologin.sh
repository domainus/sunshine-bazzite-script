#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="/etc/sddm.conf.d"
CONFIG_FILE="${CONFIG_DIR}/50-streamer-autologin.conf"

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root (sudo)." >&2
  exit 1
fi

mkdir -p "$CONFIG_DIR"

# Write autologin config just once
cat > "$CONFIG_FILE" <<CONF
[Autologin]
User=
Session=plasma
Relogin=true

[General]
DisplayServer=wayland
CONF

echo "SDDM autologin config written to $CONFIG_FILE"
echo "Autologin is disabled by default. Use systemctl to control it."

# Create toggles WITHOUT restarting sddm
LOGIN_UNIT="/etc/systemd/system/sunshine-streamer-login.service"
LOGOUT_UNIT="/etc/systemd/system/sunshine-streamer-logout.service"

cat > "$LOGIN_UNIT" <<"SERVICE"
[Unit]
Description=Enable streamer autologin when Sunshine connects
After=sunshine.service

[Service]
Type=oneshot
ExecStart=/usr/bin/sed -i 's/^User=.*/User=streamer/' /etc/sddm.conf.d/50-streamer-autologin.conf

[Install]
WantedBy=sunshine-session@streamer.service
SERVICE

cat > "$LOGOUT_UNIT" <<"SERVICE"
[Unit]
Description=Disable streamer autologin when Sunshine disconnects
After=sunshine.service

[Service]
Type=oneshot
ExecStart=/usr/bin/sed -i 's/^User=.*/User=/' /etc/sddm.conf.d/50-streamer-autologin.conf

[Install]
WantedBy=sunshine-disconnect@streamer.service
SERVICE

systemctl daemon-reload
systemctl enable sunshine-streamer-login.service
systemctl enable sunshine-streamer-logout.service

echo "SAFE configuration complete. No SDDM restart or VT switching is used."
echo "Logout required for changes to take effect."
