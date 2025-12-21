#!/usr/bin/env bash
set -euo pipefail

TARGET_USER="${SUDO_USER:-$USER}"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
DEST="${TARGET_HOME}/.local/bin"

WAKE_SCRIPT="${DEST}/force_display_wake.sh"
USER_SYSTEMD_DIR="${TARGET_HOME}/.config/systemd/user"
WAKE_UNIT="${USER_SYSTEMD_DIR}/wake_displays_from_sleep.service"

echo "Target user: $TARGET_USER ($TARGET_HOME)"

if [ -f "$WAKE_SCRIPT" ]; then
  echo "Removing $WAKE_SCRIPT"
  rm -f "$WAKE_SCRIPT"
else
  echo "Skipping missing $WAKE_SCRIPT"
fi

if [ -f "$WAKE_UNIT" ]; then
  echo "Removing $WAKE_UNIT"
  rm -f "$WAKE_UNIT"
else
  echo "Skipping missing $WAKE_UNIT"
fi

echo "Done."
