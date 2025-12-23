#!/usr/bin/env bash

prompt_reboot() {
  echo
  read -rn1 -p "Press 'r' to reboot now, or any other key to exit: " REBOOT_KEY
  echo
  if [ "$REBOOT_KEY" = "r" ]; then
    echo "Rebooting..."
    systemctl reboot
  else
    echo "Reboot skipped."
  fi
}

echo "=== Checking prerequisites ==="
missing_pkgs=()
for pkg in ruby-devel rubygems rpm-build; do
  if ! rpm -q "$pkg" >/dev/null 2>&1; then
    missing_pkgs+=("$pkg")
  fi
done

if [ "${#missing_pkgs[@]}" -gt 0 ]; then
  echo "Layering missing packages (${missing_pkgs[*]}) via rpm-ostree (requires reboot)..."
  rpm-ostree install "${missing_pkgs[@]}"
  echo "Reboot required to apply layered packages."
  prompt_reboot
  exit 0
else
  echo "All prerequisite RPM packages already installed; skipping rpm-ostree install."
fi

echo "Checking for fpm gem..."
if ! gem list -i fpm >/dev/null 2>&1; then
  echo "Installing fpm gem with sudo..."
  sudo gem install fpm
else
  echo "fpm gem already installed; skipping."
fi

echo "=== Make and install the rpm package from the bin ==="
mkdir -p ~/edid_patch/usr/lib/firmware/edid
read -rp "Enter the EDID .bin filename (e.g., my_edid.bin): " EDID_BIN
EDID_NAME="$(basename "$EDID_BIN")"
echo "Copying $EDID_BIN into firmware/edid as $EDID_NAME..."
cp "$EDID_BIN" ~/edid_patch/usr/lib/firmware/edid/"$EDID_NAME"
cd ~/edid_patch
echo "Building edid_patch RPM with fpm..."
fpm -s dir -t rpm -n edid_patch .
echo "Resetting development layered patches before installing"
rpm-ostree reset
echo "Installing generated RPM (update name if it differs)..."
rpm-ostree install $EDID_NAME

echo "=== Update initramfs with custom EDID ==="
echo "install_items+=\" /usr/lib/firmware/edid/$EDID_NAME \"" | sudo tee /etc/dracut.conf.d/99-local.conf
rpm-ostree initramfs --enable

echo "=== Add kernel argument and reboot ==="
rpm-ostree kargs --append="drm.edid_firmware=DP-3:edid/$EDID_NAME"
rpm-ostree kargs --append="video=DP-3:e"
echo "[Optional] You can specify a specific output port such as DP-3:edid/$EDID_NAME"
prompt_reboot
