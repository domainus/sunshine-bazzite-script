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

# Try to disable and detach the user units; ignore if they were never enabled or DBus isn't reachable
run_user_systemctl disable unlock-on-sunshine.service || true
run_user_systemctl disable lock-on-sunshine-exit.service || true
run_user_systemctl remove-wants sunshine.service unlock-on-sunshine.service || true
run_user_systemctl remove-wants sunshine.service lock-on-sunshine-exit.service || true
run_user_systemctl daemon-reload || true

# Remove installed files
rm -f "$UNLOCK_SCRIPT" "$LOCK_SCRIPT"
if [[ -d "$USER_SYSTEMD_DIR" ]]; then
    sudo -u "$STREAMER_USER" rm -f "$UNLOCK_USER_UNIT" "$LOCK_USER_UNIT"
    sudo -u "$STREAMER_USER" rmdir --ignore-fail-on-non-empty "$USER_SYSTEMD_DIR" 2>/dev/null || true
fi

echo "Removed Sunshine lock/unlock autologin setup for $STREAMER_USER."
