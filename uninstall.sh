#!/usr/bin/env bash
set -euo pipefail

#
# Sunshine Bazzite Uninstaller (modular + verbose)
# Use flags to pick what to remove or run interactively if no flags are set.
#
# Components:
#   --virtual-display     Remove EDID patch, dracut config, kernel args (root)
#   --sunshine-scripts    Remove user-installed Sunshine helpers + wake service
#   --streamer-autologin  Remove SDDM autologin + related systemd units (root)
#   --failsafe-service    Remove user failsafe service (runs sunshine_undo.sh)
#   --all                 Selects all components above
#   --dry-run             Print actions without executing
#   --target-user <user>  User whose home/user units were configured (defaults to sudo user)
#

usage() {
  cat <<'EOF'
Usage: sudo ./uninstall.sh [options]
  --all                 Uninstall everything (all components)
  --virtual-display     Remove EDID patch + kargs/initramfs changes (root)
  --sunshine-scripts    Remove Sunshine helper scripts + wake service (user scope)
  --streamer-autologin  Remove streamer autologin + unlock/lock hooks (root)
  --failsafe-service    Remove user failsafe display reset service
  --target-user <user>  Override target user (default: SUDO_USER or current user)
  --dry-run             Show what would happen without executing
  -h, --help            Show this help

If no component flags are given, you'll be prompted for each.
EOF
}

DRY_RUN=false
DO_ALL=false
DO_VIRTUAL=false
DO_SUNSHINE=false
DO_AUTOLOGIN=false
DO_FAILSAFE=false
TARGET_USER="${SUDO_USER:-$USER}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all) DO_ALL=true ;;
    --virtual-display) DO_VIRTUAL=true ;;
    --sunshine-scripts) DO_SUNSHINE=true ;;
    --streamer-autologin) DO_AUTOLOGIN=true ;;
    --failsafe-service) DO_FAILSAFE=true ;;
    --target-user)
      shift
      [[ $# -gt 0 ]] || { echo "Missing value for --target-user" >&2; exit 1; }
      TARGET_USER="$1"
      ;;
    --dry-run) DRY_RUN=true ;;
    -h|--help) usage; exit 0 ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
  shift
done

if $DO_ALL; then
  DO_VIRTUAL=true
  DO_SUNSHINE=true
  DO_AUTOLOGIN=true
  DO_FAILSAFE=true
fi

# Prompt if nothing chosen
if ! $DO_VIRTUAL && ! $DO_SUNSHINE && ! $DO_AUTOLOGIN && ! $DO_FAILSAFE; then
  read -rp "Remove virtual display EDID patch? [y/N]: " ans
  [[ "${ans,,}" == "y" ]] && DO_VIRTUAL=true

  read -rp "Remove Sunshine helper scripts + wake service? [y/N]: " ans
  [[ "${ans,,}" == "y" ]] && DO_SUNSHINE=true

  read -rp "Remove streamer autologin + hooks? [y/N]: " ans
  [[ "${ans,,}" == "y" ]] && DO_AUTOLOGIN=true

  read -rp "Remove failsafe display reset service? [y/N]: " ans
  [[ "${ans,,}" == "y" ]] && DO_FAILSAFE=true
fi

run_cmd() {
  if $DRY_RUN; then
    echo "[dry-run] $*"
  else
    echo "+ $*"
    eval "$@"
  fi
}

require_user_exists() {
  if ! getent passwd "$TARGET_USER" >/dev/null; then
    echo "Target user '$TARGET_USER' not found." >&2
    exit 1
  fi
}

TARGET_UID=""
TARGET_HOME=""
if $DO_SUNSHINE || $DO_FAILSAFE; then
  require_user_exists
  TARGET_UID="$(id -u "$TARGET_USER")"
  TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
  echo "Target user: $TARGET_USER (uid: $TARGET_UID, home: $TARGET_HOME)"
fi

user_cmd() {
  local cmd="$1"
  if $DRY_RUN; then
    echo "[dry-run][user:$TARGET_USER] $cmd"
  else
    echo "+ (as $TARGET_USER) $cmd"
    sudo -u "$TARGET_USER" env XDG_RUNTIME_DIR="/run/user/${TARGET_UID}" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${TARGET_UID}/bus" bash -lc "$cmd"
  fi
}

require_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "This step requires root. Re-run with sudo." >&2
    exit 1
  fi
}

NEED_REBOOT=false

remove_virtual_display() {
  require_root
  echo "=== Removing EDID patch (virtual display) ==="
  local edid_pkg
  edid_pkg=$(rpm-ostree status | awk '/edid_patch/ { for (i = 1; i <= NF; i++) if ($i ~ /^edid_patch/) { print $i; exit } }')
  if [[ -z "$edid_pkg" ]]; then
    echo "No edid_patch package found; skipping rpm-ostree uninstall."
  else
    run_cmd "rpm-ostree uninstall $edid_pkg"
    NEED_REBOOT=true
  fi

  if [[ -f /etc/dracut.conf.d/99-local.conf ]]; then
    run_cmd "rm -f /etc/dracut.conf.d/99-local.conf"
  else
    echo "dracut config not present; skipping."
  fi

  echo "Checking for drm.edid_firmware kernel args..."
  mapfile -t kargs < <(rpm-ostree kargs | tr ' ' '\n' | grep -E '^drm\.edid_firmware=' || true)
  if [[ ${#kargs[@]} -eq 0 ]]; then
    echo "No EDID kernel args found; skipping."
  else
    for k in "${kargs[@]}"; do
      run_cmd "rpm-ostree kargs --delete=\"$k\""
      NEED_REBOOT=true
    done
  fi

  echo "Disabling custom initramfs (if enabled)..."
  run_cmd "rpm-ostree initramfs --disable || true"
  NEED_REBOOT=true
}

remove_sunshine_scripts() {
  echo "=== Removing Sunshine helper scripts and wake hooks ==="
  local dest="${TARGET_HOME}/.local/bin"
  local files=(
    "sunshine_do.sh"
    "sunshine_undo.sh"
    "sunshine_sleep.sh"
    "sunshine_cancel_sleep.sh"
    "force_display_wake.sh"
    "unlock_on_connect.sh"
  )
  for f in "${files[@]}"; do
    if [[ -f "$dest/$f" ]]; then
      run_cmd "rm -f \"$dest/$f\""
    else
      echo "Missing: $dest/$f (skipping)"
    fi
  done

  local config="${TARGET_HOME}/.config/sunshine/sunshine.conf"
  if [[ -f "$config" ]]; then
    run_cmd "rm -f \"$config\""
  else
    echo "Missing: $config (skipping)"
  fi

  local wake_unit="${TARGET_HOME}/.config/systemd/user/wake_displays_from_sleep.service"
  user_cmd "systemctl --user disable --now wake_displays_from_sleep.service || true"
  if [[ -f "$wake_unit" ]]; then
    run_cmd "rm -f \"$wake_unit\""
  else
    echo "Missing: $wake_unit (skipping)"
  fi

  local system_wake="/etc/systemd/system-sleep/99-force-display-wake"
  if [[ -f "$system_wake" ]]; then
    run_cmd "rm -f \"$system_wake\""
  else
    echo "Missing: $system_wake (skipping)"
  fi

  local system_script="/usr/local/bin/force_display_wake.sh"
  if [[ -f "$system_script" ]]; then
    run_cmd "rm -f \"$system_script\""
  else
    echo "Missing: $system_script (skipping)"
  fi

  local sudoers_file="/etc/sudoers.d/sunshine-loginctl"
  if [[ -f "$sudoers_file" ]]; then
    echo "Removing sudoers drop-in $sudoers_file"
    run_cmd "rm -f \"$sudoers_file\""
  else
    echo "Sudoers drop-in not present; skipping."
  fi
}

remove_streamer_autologin() {
  require_root
  echo "=== Removing streamer autologin + Sunshine hooks (system) ==="
  local units=(
    "sunshine-streamer-login.service"
    "sunshine-streamer-logout.service"
    "unlock-streamer-on-resume.service"
    "lock-streamer-on-sunshine-exit.service"
  )
  for u in "${units[@]}"; do
    run_cmd "systemctl disable --now $u || true"
    if [[ -f "/etc/systemd/system/$u" ]]; then
      run_cmd "rm -f /etc/systemd/system/$u"
    fi
  done

  local conf="/etc/sddm.conf.d/50-streamer-autologin.conf"
  if [[ -f "$conf" ]]; then
    run_cmd "rm -f \"$conf\""
  else
    echo "SDDM autologin config not present; skipping."
  fi

  run_cmd "systemctl daemon-reload"
}

remove_failsafe_service() {
  echo "=== Removing failsafe display reset service (user) ==="
  local svc="failsafe_displays.service"
  user_cmd "systemctl --user disable --now $svc || true"
  local path="${TARGET_HOME}/.config/systemd/user/${svc}"
  if [[ -f "$path" ]]; then
    run_cmd "rm -f \"$path\""
  else
    echo "Missing: $path (skipping)"
  fi
}

$DO_VIRTUAL && remove_virtual_display
$DO_SUNSHINE && remove_sunshine_scripts
$DO_AUTOLOGIN && remove_streamer_autologin
$DO_FAILSAFE && remove_failsafe_service

if $DRY_RUN; then
  echo "Dry run complete. No changes were made."
else
  echo "Uninstall steps finished."
  if $NEED_REBOOT; then
    echo "Reboot recommended to finalize rpm-ostree/initramfs changes."
  fi
fi
