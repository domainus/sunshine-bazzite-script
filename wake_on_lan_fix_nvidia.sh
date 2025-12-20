#!/usr/bin/env bash
set -euo pipefail

# Creates a resume hook to wake NVIDIA displays after suspend.

service_name="nvidia-display-wake.service"
service_path="/etc/systemd/system/${service_name}"

mode="loginctl"
# Allow switching the resume "poke" method for different desktops/setups.
for arg in "$@"; do
  case "${arg}" in
    --mode=loginctl|--mode=xset|--mode=kscreen)
      mode="${arg#*=}"
      ;;
    -h|--help)
      cat <<'EOF'
Usage: wake_on_lan_fix_nvidia.sh [--mode=loginctl|xset|kscreen]

Creates and enables a systemd resume hook that pokes NVIDIA displays awake.
EOF
      exit 0
      ;;
    *)
      echo "Unknown argument: ${arg}" >&2
      exit 1
      ;;
  esac
done

case "${mode}" in
  loginctl)
    # Triggers a modeset by unlocking sessions.
    exec_start="/usr/bin/bash -c 'sleep 2; /usr/bin/loginctl unlock-sessions'"
    ;;
  xset)
    # Stronger poke via DPMS on X11.
    exec_start="/usr/bin/bash -c 'sleep 2; /usr/bin/xset dpms force on || true'"
    ;;
  kscreen)
    # KDE Wayland refresh using kscreen-doctor.
    exec_start="/usr/bin/bash -c 'sleep 2; /usr/bin/kscreen-doctor -r || true'"
    ;;
esac

# Write the systemd unit to run after resume.
sudo tee "${service_path}" >/dev/null <<EOF
[Unit]
Description=Wake NVIDIA displays after resume
After=suspend.target

[Service]
Type=oneshot
ExecStart=${exec_start}

[Install]
WantedBy=suspend.target
EOF

sudo systemctl daemon-reload
# Enable and start the unit immediately so it takes effect now.
sudo systemctl enable --now "${service_name}"

echo "Installed and enabled ${service_name} with mode=${mode}."
echo "If this does not fully fix it, rerun with --mode=xset or --mode=kscreen."
