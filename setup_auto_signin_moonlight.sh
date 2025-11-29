#!/usr/bin/env bash

set -euo pipefail

# Configures Sunshine to unlock the current user's session when a client connects.

require_deps() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "jq is required but not installed. Please install jq and re-run." >&2
    exit 1
  fi
}

detect_target_user() {
  TARGET_USER="${SUDO_USER:-$USER}"
  TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
  if [[ -z ${TARGET_HOME:-} || ! -d "$TARGET_HOME" ]]; then
    echo "Could not determine home directory for user $TARGET_USER" >&2
    exit 1
  fi
}

create_unlock_script() {
  local scripts_dir="$TARGET_HOME/.config/sunshine/scripts"
  local unlock_script="$scripts_dir/unlock-on-connect.sh"

  echo "Creating unlock script at $unlock_script..."
  mkdir -p "$scripts_dir"
  cat >"$unlock_script" <<EOF
#!/usr/bin/env bash
# Unlocks the ${TARGET_USER} session when Sunshine client connects
sleep 3
/usr/bin/loginctl unlock-user ${TARGET_USER}
EOF
  chmod +x "$unlock_script"
}

update_sunshine_config() {
  local config_dir="$TARGET_HOME/.config/sunshine"
  local config_file="$config_dir/sunshine.conf"
  local unlock_script="$TARGET_HOME/.config/sunshine/scripts/unlock-on-connect.sh"

  mkdir -p "$config_dir"

  if [[ ! -f "$config_file" || ! -s "$config_file" ]]; then
    echo "Creating new sunshine.conf..."
    printf '{\n  "on_client_connected": ["%s"]\n}\n' "$unlock_script" >"$config_file"
  else
    echo "sunshine.conf exists; appending unlock hook line..."
    printf '\n.on_client_connected = (((.on_client_connected // []) + ["%s"]) | unique)\n' "$unlock_script" >>"$config_file"
  fi
}

main() {
  require_deps
  detect_target_user
  create_unlock_script
  update_sunshine_config
  echo "Setup complete. Sunshine will unlock ${TARGET_USER} when a client connects."
}

main "$@"
