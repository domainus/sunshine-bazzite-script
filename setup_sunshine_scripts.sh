#!/usr/bin/env bash
set -euo pipefail

TARGET_USER="${SUDO_USER:-$USER}"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
DEST="${TARGET_HOME}/.local/bin"
echo "Target user: $TARGET_USER ($TARGET_HOME)"
echo "Ensuring destination exists: $DEST"
mkdir -p "$DEST"

for script in sunshine_do.sh sunshine_undo.sh; do
  if [ ! -f "$script" ]; then
    echo "Error: $script not found in current directory. Aborting."
    exit 1
  fi

  echo "Copying $script to $DEST"
  cp "$script" "$DEST/"

  echo "Making $DEST/$script executable"
  chmod +x "$DEST/$script"
done

echo "Done. Scripts installed to $DEST"

CONFIG_DIR="${TARGET_HOME}/.config/sunshine"
CONFIG="${CONFIG_DIR}/sunshine.conf"
echo "Writing global_prep_cmd to $CONFIG"
mkdir -p "$CONFIG_DIR"
cat > "$CONFIG" <<'EOF'
global_prep_cmd = [{"do":"bash -c \"${HOME}/.local/bin/sunshine_do.sh \\\"${SUNSHINE_CLIENT_WIDTH}\\\" \\\"${SUNSHINE_CLIENT_HEIGHT}\\\" \\\"${SUNSHINE_CLIENT_FPS}\\\" \\\"${SUNSHINE_CLIENT_HDR}\\\"\"","undo":"bash -c \"${HOME}/.local/bin/sunshine_undo.sh\""}]
EOF
echo "sunshine.conf written. Setup complete."
