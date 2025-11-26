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

echo "=== Preparing new EDID payload ==="
read -rp "Enter the EDID .bin filename (e.g., my_edid.bin): " EDID_BIN
EDID_NAME="$(basename "$EDID_BIN")"
echo "Copying $EDID_NAME into firmware/edid..."
cp "$EDID_NAME" ~/edid_patch/usr/lib/firmware/edid/
cd ~/edid_patch
if [ -f "$EDID_RPM.old" ]; then
  echo "Removing previous backup $EDID_RPM.old"
  rm -f "$EDID_RPM.old"
fi
if [ -f "$EDID_RPM" ]; then
  echo "Backing up existing RPM to $EDID_RPM.old"
  mv "$EDID_RPM" "$EDID_RPM.old"
fi
echo "Building new edid_patch RPM with fpm..."
fpm -s dir -t rpm -n edid_patch .
echo "Installing new edid_patch RPM..."
rpm-ostree install "$EDID_RPM"
echo "Rebooting to apply updated EDID..."
systemctl reboot
