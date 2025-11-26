#!/usr/bin/env bash

echo "=== Detecting installed edid_patch RPM ==="
EDID_PKG=$(rpm-ostree status | awk '/edid_patch/ { for (i = 1; i <= NF; i++) if ($i ~ /^edid_patch/) { print $i; exit } }')
if [ -z "$EDID_PKG" ]; then
  echo "No edid_patch package found in rpm-ostree status. Aborting."
  exit 1
fi
EDID_RPM="${EDID_PKG}.rpm"
echo "Found package: $EDID_PKG"

echo "=== Uninstalling current edid_patch ==="
rpm-ostree uninstall "$EDID_PKG"

echo "=== Removing dracut EDID config ==="
rm /etc/dracut.conf.d/99-local.conf

echo "=== Removing Sunshine Scripts ==="
rm ~/.local/bin/sunshine_do.sh
rm ~/.local/bin/sunshine_undo.sh

echo "=== Detecting EDID kernel arg ==="
EDID_KARG=$(rpm-ostree kargs | tr ' ' '\n' | grep -m1 'drm.edid_firmware=edid/')
if [ -z "$EDID_KARG" ]; then
  echo "No drm.edid_firmware=edid/... kernel arg found; skipping karg removal."
else
  echo "Removing kernel arg: $EDID_KARG"
  rpm-ostree kargs --delete="$EDID_KARG"
fi

echo "=== Disabling custom initramfs ==="
rpm-ostree initramfs --disable

echo "=== Rebooting to finalize uninstall ==="
systemctl reboot
