#!/usr/bin/env bash
set -e

echo "=== Sunshine VKMS Streaming System Uninstaller ==="

########################################
# 1. Stop services
########################################

echo "Stopping services..."
systemctl disable --now sunshine-xorg.service 2>/dev/null || true
systemctl disable --now sunshine@streamer 2>/dev/null || true
systemctl disable getty@tty99.service 2>/dev/null || true

########################################
# 2. Remove systemd services + configs
########################################

echo "Removing systemd units..."
rm -f /etc/systemd/system/sunshine-xorg.service
rm -rf /etc/systemd/system/getty@tty99.service.d

########################################
# 3. Remove VKMS & Xorg configs
########################################

echo "Removing VKMS + Xorg configs..."
rm -f /etc/modprobe.d/vkms.conf
rm -f /etc/X11/xorg.conf.d/10-vkms.conf

########################################
# 4. Remove VKMS kernel args
########################################

echo "Cleaning kernel args..."
rpm-ostree kargs --delete=rd.driver.pre=vkms 2>/dev/null || true

########################################
# 5. Delete Sunshine cleanup hook
########################################

rm -f /usr/local/bin/sunshine-cleanup.sh

########################################
# 6. Remove streamer autostarts + Sunshine configs
########################################

if id "streamer" &>/dev/null; then
    echo "Removing streamer autostart + config files..."
    rm -rf /home/streamer/.config/autostart/gamescope.desktop 2>/dev/null || true
    rm -rf /home/streamer/.config/autostart/steam.desktop 2>/dev/null || true
    rm -rf /home/streamer/.config/sunshine 2>/dev/null || true
fi

########################################
# 7. Ask whether to remove the streamer user
########################################

if id "streamer" &>/dev/null; then
    read -p "Do you want to DELETE the 'streamer' user entirely? [y/N]: " deluser
    if [[ "$deluser" =~ ^[Yy]$ ]]; then
        echo "Deleting user streamer..."
        userdel -r streamer 2>/dev/null || true
    else
        echo "User 'streamer' kept."
    fi
fi

########################################
# 8. Final message
########################################

echo "============================================================"
echo "🎉 Uninstall complete!"
echo "A reboot is recommended to fully remove VKMS + Xorg remnants."
echo "============================================================"
