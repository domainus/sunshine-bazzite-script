#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

UI_BIN=""
if command -v whiptail >/dev/null 2>&1; then
  UI_BIN="whiptail"
elif command -v dialog >/dev/null 2>&1; then
  UI_BIN="dialog"
else
  UI_BIN="text"
  if [[ ! -t 0 ]]; then
    echo "Error: no TTY available for text UI." >&2
    exit 1
  fi
fi

ui_msgbox() {
  local title="$1"
  local message="$2"
  if [[ "$UI_BIN" == "dialog" ]]; then
    dialog --title "$title" --msgbox "$message" 10 70
  elif [[ "$UI_BIN" == "whiptail" ]]; then
    whiptail --title "$title" --msgbox "$message" 10 70
  else
    printf "\n[%s]\n%s\n\nPress Enter to continue..." "$title" "$message"
    read -r
  fi
}

ui_yesno() {
  local title="$1"
  local message="$2"
  if [[ "$UI_BIN" == "dialog" ]]; then
    dialog --title "$title" --yesno "$message" 10 70
  elif [[ "$UI_BIN" == "whiptail" ]]; then
    whiptail --title "$title" --yesno "$message" 10 70
  else
    local answer
    printf "\n[%s]\n%s [y/N]: " "$title" "$message"
    read -r answer
    [[ "${answer:-}" == "y" || "${answer:-}" == "Y" ]]
  fi
}

ui_inputbox() {
  local title="$1"
  local message="$2"
  local default="$3"
  if [[ "$UI_BIN" == "dialog" ]]; then
    dialog --stdout --title "$title" --inputbox "$message" 10 70 "$default"
  elif [[ "$UI_BIN" == "whiptail" ]]; then
    whiptail --title "$title" --inputbox "$message" 10 70 "$default" 3>&1 1>&2 2>&3
  else
    local value
    printf "\n[%s]\n%s [%s]: " "$title" "$message" "$default"
    read -r value
    if [[ -z "${value:-}" ]]; then
      printf '%s\n' "$default"
    else
      printf '%s\n' "$value"
    fi
  fi
}

ui_radiolist() {
  local title="$1"
  local message="$2"
  shift 2
  if [[ "$UI_BIN" == "dialog" ]]; then
    dialog --stdout --title "$title" --radiolist "$message" 12 70 5 "$@"
  elif [[ "$UI_BIN" == "whiptail" ]]; then
    whiptail --title "$title" --radiolist "$message" 12 70 5 "$@" 3>&1 1>&2 2>&3
  else
    local i=1
    local options=()
    local descs=()
    local default_idx=1
    while (($#)); do
      options+=("$1")
      shift
      descs+=("$1")
      shift
      if [[ "${1:-}" == "ON" ]]; then
        default_idx="$i"
      fi
      shift
      i=$((i + 1))
    done
    printf "\n[%s]\n%s\n" "$title" "$message"
    local idx=1
    local j
    for j in "${!options[@]}"; do
      printf "  %d) %s - %s\n" "$idx" "${options[$j]}" "${descs[$j]}"
      idx=$((idx + 1))
    done
    printf "Select [%s]: " "$default_idx"
    local pick
    read -r pick
    pick=${pick:-$default_idx}
    printf '%s\n' "${options[$((pick - 1))]}"
  fi
}

ui_menu() {
  local title="$1"
  local message="$2"
  shift 2
  if [[ "$UI_BIN" == "dialog" ]]; then
    dialog --stdout --title "$title" --menu "$message" 20 78 12 "$@"
  elif [[ "$UI_BIN" == "whiptail" ]]; then
    whiptail --title "$title" --menu "$message" 20 78 12 "$@" 3>&1 1>&2 2>&3
  else
    local tags=()
    local descs=()
    while (($#)); do
      tags+=("$1")
      shift
      descs+=("$1")
      shift
    done
    printf "\n[%s]\n%s\n" "$title" "$message"
    local idx=1
    local i
    for i in "${!tags[@]}"; do
      printf "  %d) %s - %s\n" "$idx" "${tags[$i]}" "${descs[$i]}"
      idx=$((idx + 1))
    done
    printf "Select: "
    local pick
    read -r pick
    pick=${pick:-1}
    printf '%s\n' "${tags[$((pick - 1))]}"
  fi
}

ui_textbox() {
  local title="$1"
  local file="$2"
  if [[ "$UI_BIN" == "dialog" ]]; then
    dialog --title "$title" --textbox "$file" 20 78
  elif [[ "$UI_BIN" == "whiptail" ]]; then
    whiptail --title "$title" --textbox "$file" 20 78
  else
    printf "\n[%s]\n" "$title"
    if command -v less >/dev/null 2>&1; then
      less "$file"
    else
      cat "$file"
      printf "\nPress Enter to continue..."
      read -r
    fi
  fi
}

ensure_script() {
  local name="$1"
  local path="${SCRIPT_DIR}/${name}"
  if [[ ! -f "$path" ]]; then
    ui_msgbox "Missing Script" "Could not find ${path}."
    return 1
  fi
  echo "$path"
}

run_script() {
  local title="$1"
  local needs_root="$2"
  shift 2
  local cmd=("$@")

  if [[ "$needs_root" == "true" && "$EUID" -ne 0 ]]; then
    if ! command -v sudo >/dev/null 2>&1; then
      ui_msgbox "Missing sudo" "This action needs sudo, but sudo is not available."
      return 1
    fi
    cmd=(sudo "${cmd[@]}")
  fi

  local tmp
  tmp="$(mktemp)"
  clear
  printf "Running: %s\n\n" "${cmd[*]}"
  set +e
  "${cmd[@]}" 2>&1 | tee "$tmp"
  local status="${PIPESTATUS[0]}"
  set -e
  printf "\nExit status: %s\n" "$status"
  printf "Press Enter to continue..."
  read -r
  ui_textbox "${title} output" "$tmp"
  rm -f "$tmp"
  return "$status"
}

sunshine_do_custom() {
  local width height fps hdr
  width="$(ui_inputbox "Sunshine Prep" "Width" "3840")" || return 1
  height="$(ui_inputbox "Sunshine Prep" "Height" "2160")" || return 1
  fps="$(ui_inputbox "Sunshine Prep" "FPS" "120")" || return 1
  hdr="$(ui_radiolist "Sunshine Prep" "HDR enabled?" \
    "true" "Enable HDR" ON \
    "false" "Disable HDR" OFF)" || return 1

  local script
  script="$(ensure_script "sunshine_do.sh")" || return 1
  run_script "Sunshine Prep" "false" bash "$script" "$width" "$height" "$fps" "$hdr"
}

run_menu() {
  local choice
  choice="$(ui_menu "Sunshine Tools" "Select an action:" \
    "sunshine_do" "Sunshine prep (defaults)" \
    "sunshine_do_custom" "Sunshine prep (custom args)" \
    "sunshine_undo" "Sunshine undo" \
    "sunshine_sleep" "Start 60s sleep timer" \
    "sunshine_cancel_sleep" "Cancel sleep timer" \
    "fix_displays" "Fix displays (DP on, HDMI off)" \
    "virtual_display_setup" "Install virtual display EDID (sudo)" \
    "virtual_display_update" "Update virtual display EDID (sudo)" \
    "virtual_display_uninstall" "Remove virtual display EDID (sudo)" \
    "setup_sunshine_scripts" "Install Sunshine helper scripts" \
    "setup_startup_failsafe_service" "Install startup failsafe service" \
    "wake_on_lan_fix_nvidia" "Install NVIDIA wake service (sudo)" \
    "uninstall_wake_on_lan_fix_nvidia" "Remove NVIDIA wake service (sudo)" \
    "nvidia_resume_fix" "Install KDE Wayland resume fix (sudo)" \
    "undo_display_wake_fix" "Remove display wake files" \
    "uninstall" "Run modular uninstall (sudo)" \
    "view_readme" "View README" \
    "quit" "Exit")" || return 1

  case "$choice" in
    sunshine_do)
      run_script "Sunshine Prep" "false" bash "$(ensure_script "sunshine_do.sh")"
      ;;
    sunshine_do_custom)
      sunshine_do_custom
      ;;
    sunshine_undo)
      run_script "Sunshine Undo" "false" bash "$(ensure_script "sunshine_undo.sh")"
      ;;
    sunshine_sleep)
      run_script "Sunshine Sleep" "false" bash "$(ensure_script "sunshine_sleep.sh")"
      ;;
    sunshine_cancel_sleep)
      run_script "Sunshine Cancel Sleep" "false" bash "$(ensure_script "sunshine_cancel_sleep.sh")"
      ;;
    fix_displays)
      run_script "Fix Displays" "false" bash "$(ensure_script "fix_displays.sh")"
      ;;
    virtual_display_setup)
      ui_yesno "Confirm" "Install the virtual display EDID (requires sudo)?" || return 0
      run_script "Virtual Display Setup" "true" bash "$(ensure_script "virtual_display_setup.sh")"
      ;;
    virtual_display_update)
      ui_yesno "Confirm" "Update the virtual display EDID (requires sudo)?" || return 0
      run_script "Virtual Display Update" "true" bash "$(ensure_script "virtual_display_update.sh")"
      ;;
    virtual_display_uninstall)
      ui_yesno "Confirm" "Remove the virtual display EDID (requires sudo)?" || return 0
      run_script "Virtual Display Uninstall" "true" bash "$(ensure_script "virtual_display_uninstall.sh")"
      ;;
    setup_sunshine_scripts)
      run_script "Setup Sunshine Scripts" "false" bash "$(ensure_script "setup_sunshine_scripts.sh")"
      ;;
    setup_startup_failsafe_service)
      run_script "Setup Startup Failsafe" "false" bash "$(ensure_script "setup_startup_failsafe_service.sh")"
      ;;
    wake_on_lan_fix_nvidia)
      local mode
      mode="$(ui_radiolist "NVIDIA Wake Fix" "Select wake mode:" \
        "loginctl" "Unlock sessions" ON \
        "xset" "DPMS on (X11)" OFF \
        "kscreen" "KScreen refresh (KDE Wayland)" OFF)" || return 0
      ui_yesno "Confirm" "Install NVIDIA wake fix (requires sudo)?" || return 0
      run_script "NVIDIA Wake Fix" "true" bash "$(ensure_script "wake_on_lan_fix_nvidia.sh")" "--mode=${mode}"
      ;;
    uninstall_wake_on_lan_fix_nvidia)
      ui_yesno "Confirm" "Remove NVIDIA wake fix (requires sudo)?" || return 0
      run_script "Remove NVIDIA Wake Fix" "true" bash "$(ensure_script "uninstall_wake_on_lan_fix_nvidia.sh")"
      ;;
    nvidia_resume_fix)
      ui_yesno "Confirm" "Install KDE Wayland resume fix (requires sudo)?" || return 0
      run_script "NVIDIA Resume Fix" "true" bash "$(ensure_script "nvidia-resume-fix.sh")"
      ;;
    undo_display_wake_fix)
      ui_yesno "Confirm" "Remove display wake helper files?" || return 0
      run_script "Remove Display Wake Fix" "false" bash "$(ensure_script "undo_display_wake_fix.sh")"
      ;;
    uninstall)
      ui_yesno "Confirm" "Run the modular uninstall (requires sudo)?" || return 0
      run_script "Uninstall" "true" bash "$(ensure_script "uninstall.sh")"
      ;;
    view_readme)
      ui_textbox "README" "${SCRIPT_DIR}/README.md"
      ;;
    quit)
      return 1
      ;;
  esac
}

while true; do
  run_menu || break
done

clear
echo "Done."
