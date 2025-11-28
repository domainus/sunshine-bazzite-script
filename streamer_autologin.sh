#!/usr/bin/env bash
set -euo pipefail
UNLOCK_SCRIPT="/usr/local/bin/unlock-streamer.sh"
LOCK_SCRIPT="/usr/local/bin/lock-streamer.sh"
UNLOCK_SERVICE="/etc/systemd/system/unlock-streamer-on-sunshine.service"
LOCK_SERVICE="/etc/systemd/system/lock-streamer-on-sunshine.service"

cat > "$UNLOCK_SCRIPT" <<"SCRIPT"
#!/usr/bin/env bash

session=$(loginctl list-sessions | awk '$1 ~ /^[0-9]+$/ && $3=="streamer" {print $1}')

if [[ -n "$session" ]]; then
    loginctl unlock-session "$session"
fi
SCRIPT
chmod +x "$UNLOCK_SCRIPT"

cat > "$LOCK_SCRIPT" <<"SCRIPT"
#!/usr/bin/env bash

session=$(loginctl list-sessions | awk '$1 ~ /^[0-9]+$/ && $3=="streamer" {print $1}')

if [[ -n "$session" ]]; then
    loginctl lock-session "$session"
fi
SCRIPT
chmod +x "$LOCK_SCRIPT"

cat > "$UNLOCK_SERVICE" <<"SERVICE"
[Unit]
Description=Unlock streamer when Sunshine client begins streaming
After=sunshine-streaming.service
Requires=sunshine-streaming.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/unlock-streamer.sh

[Install]
WantedBy=sunshine-streaming.service
SERVICE

cat > "$LOCK_SERVICE" <<"SERVICE"
[Unit]
Description=Lock streamer when Sunshine client stops streaming
After=sunshine.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/lock-streamer.sh

[Install]
WantedBy=sunshine.service
SERVICE

systemctl daemon-reload
systemctl enable --now unlock-streamer-on-sunshine.service
echo "Auto-unlock on Sunshine start enabled for user streamer (unlock-streamer-on-sunshine.service)."

systemctl enable --now lock-streamer-on-sunshine.service
echo "Auto-lock on Sunshine stop enabled for user streamer (lock-streamer-on-sunshine.service)."
