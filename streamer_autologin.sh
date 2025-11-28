#!/usr/bin/env bash
set -euo pipefail
STREAMER_USER="${STREAMER_USER:-streamer}"
STREAMER_HOME="$(getent passwd "$STREAMER_USER" | cut -d: -f6 || true)"
STREAMER_UID="$(id -u "$STREAMER_USER" 2>/dev/null || true)"

if [[ -z "$STREAMER_HOME" || ! -d "$STREAMER_HOME" ]]; then
    echo "Could not resolve home for user '$STREAMER_USER'." >&2
    exit 1
fi
if [[ -z "$STREAMER_UID" ]]; then
    echo "Could not resolve UID for user '$STREAMER_USER'." >&2
    exit 1
fi

UNLOCK_SCRIPT="/usr/local/bin/unlock-streamer.sh"
LOCK_SCRIPT="/usr/local/bin/lock-streamer.sh"
USER_SYSTEMD_DIR="$STREAMER_HOME/.config/systemd/user"
UNLOCK_USER_UNIT="$USER_SYSTEMD_DIR/unlock-on-sunshine.service"
LOCK_USER_UNIT="$USER_SYSTEMD_DIR/lock-on-sunshine-exit.service"
USER_RUNTIME_DIR="/run/user/$STREAMER_UID"
USER_DBUS_ADDR="unix:path=$USER_RUNTIME_DIR/bus"

run_user_systemctl() {
    sudo -u "$STREAMER_USER" XDG_RUNTIME_DIR="$USER_RUNTIME_DIR" DBUS_SESSION_BUS_ADDRESS="$USER_DBUS_ADDR" systemctl --user "$@"
}

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

sudo -u "$STREAMER_USER" mkdir -p "$USER_SYSTEMD_DIR"

sudo -u "$STREAMER_USER" /bin/bash -c "cat > \"$UNLOCK_USER_UNIT\" <<'SERVICE'
[Unit]
Description=Unlock streamer session when Sunshine starts streaming
After=sunshine.service
Requires=sunshine.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/unlock-streamer.sh
[Install]
WantedBy=sunshine.service
SERVICE"

sudo -u "$STREAMER_USER" /bin/bash -c "cat > \"$LOCK_USER_UNIT\" <<'SERVICE'
[Unit]
Description=Lock streamer session when Sunshine stops streaming
After=sunshine.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/lock-streamer.sh
[Install]
WantedBy=sunshine.service
SERVICE"

run_user_systemctl daemon-reload
run_user_systemctl enable unlock-on-sunshine.service
run_user_systemctl enable lock-on-sunshine-exit.service

run_user_systemctl add-wants sunshine.service unlock-on-sunshine.service
run_user_systemctl add-wants sunshine.service lock-on-sunshine-exit.service

echo "User-level Sunshine lock/unlock units enabled for $STREAMER_USER."
