#!/usr/bin/env bash
set -euo pipefail
UNLOCK_ON_RESUME_UNIT="/etc/systemd/system/unlock-streamer-on-resume.service"

cat > "$UNLOCK_ON_RESUME_UNIT" <<"SERVICE"
[Unit]
Description=Auto-unlock streamer session on resume
After=suspend.target
PartOf=sunshine-session@streamer.service

[Service]
Type=oneshot
ExecStart=/usr/bin/loginctl unlock-user streamer

[Install]
WantedBy=sunshine-session@streamer.service
SERVICE
systemctl daemon-reload
systemctl enable --now unlock-streamer-on-resume.service
echo "Auto-unlock on resume enabled for user streamer (unlock-streamer-on-resume.service)."

# Optional: relock the session when Sunshine disconnects
LOCK_ON_EXIT_UNIT="/etc/systemd/system/lock-streamer-on-sunshine-exit.service"

cat > "$LOCK_ON_EXIT_UNIT" <<"SERVICE"
[Unit]
Description=Lock streamer when Sunshine client disconnects
After=sunshine.service
PartOf=sunshine-disconnect@streamer.service

[Service]
Type=oneshot
ExecStart=/usr/bin/loginctl lock-user streamer

[Install]
WantedBy=sunshine-disconnect@streamer.service
SERVICE

systemctl enable --now lock-streamer-on-sunshine-exit.service
echo "Auto-lock on Sunshine disconnect enabled for user streamer (lock-streamer-on-sunshine-exit.service)."
