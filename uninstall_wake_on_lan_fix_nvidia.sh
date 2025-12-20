#!/usr/bin/env bash
set -euo pipefail

# Removes the NVIDIA display wake resume hook.
service_name="nvidia-display-wake.service"
service_path="/etc/systemd/system/${service_name}"

sudo systemctl disable --now "${service_name}" >/dev/null 2>&1 || true
sudo rm -f "${service_path}"
sudo systemctl daemon-reload

echo "Removed ${service_name} (if it was installed)."
