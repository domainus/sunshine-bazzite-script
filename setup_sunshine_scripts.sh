#!/usr/bin/env bash
set -euo pipefail

DEST="${HOME}/.local/bin"
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

CONFIG="${HOME}/.config/sunshine.conf"
echo "Writing global_prep_cmd to $CONFIG"
mkdir -p "$(dirname "$CONFIG")"
cat > "$CONFIG" <<'EOF'
global_prep_cmd = [{"do":"bash -c \"${HOME}/.local/bin/sunshine-do.sh \\\"${SUNSHINE_CLIENT_WIDTH}\\\" \\\"${SUNSHINE_CLIENT_HEIGHT}\\\" \\\"${SUNSHINE_CLIENT_FPS}\\\" \\\"${SUNSHINE_CLIENT_HDR}\\\"\"","undo":"bash -c \"${HOME}/.local/bin/sunshine-undo.sh\""}]
EOF
echo "sunshine.conf written. Setup complete."
