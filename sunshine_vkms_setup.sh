#!/usr/bin/env bash
set -e

echo "=== Creating streaming user ==="
if ! id "streamer" &>/dev/null; then
    useradd -m -G video,render,tty streamer
    echo "Set password for 'streamer':"
    passwd streamer
else
    echo "User 'streamer' already exists. Skipping."
fi

echo "=== Enabling VKMS kernel module ==="
mkdir -p /etc/modprobe.d
cat >/etc/modprobe.d/vkms.conf <<EOF
options vkms enable_cursor=1 enable_overlay=1 num_connectors=1
EOF

echo "=== Adding VKMS to kernel args ==="
rpm-ostree kargs --append-if-missing=rd.driver.pre=vkms

echo "=== Installing Xorg server (immutable) ==="
rpm-ostree install xorg-x11-server-Xorg

echo "=== Creating Xorg VKMS config ==="
mkdir -p /etc/X11/xorg.conf.d
cat >/etc/X11/xorg.conf.d/10-vkms.conf <<EOF
Section "Device"
    Identifier "VKMS"
    Driver "modesetting"
    BusID "PCI:0:0:0"
EndSection
EOF

echo "=== Creating headless Xorg systemd service ==="
cat >/etc/systemd/system/sunshine-xorg.service <<EOF
[Unit]
Description=Headless Xorg session for Sunshine via VKMS
After=multi-user.target

[Service]
User=streamer
Environment=DISPLAY=:99
Environment=XDG_SESSION_TYPE=x11
ExecStart=/usr/bin/Xorg :99 -nolisten tcp -noreset -novtswitch -sharevts -logfile /var/log/Xorg-vkms.log
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl enable sunshine-xorg.service

echo "=== Ensuring Sunshine installed ==="
if ! command -v sunshine &>/dev/null; then
    ujust setup-sunshines
    echo "Sunshine installed. Reboot required before continuing."
    exit 0
fi

echo "=== Configuring Sunshine for streamer user ==="
sudo -u streamer mkdir -p /home/streamer/.config/sunshine

cat >/home/streamer/.config/sunshine/sunshine.conf <<EOF
display = :99
auto_start = true
EOF

chown -R streamer:streamer /home/streamer/.config/sunshine

echo "=== Enabling Sunshine service for streamer ==="
systemctl enable --now sunshine@streamer

echo "=== Creating auto-login on virtual TTY ==="
mkdir -p /etc/systemd/system/getty@tty99.service.d
cat >/etc/systemd/system/getty@tty99.service.d/override.conf <<EOF
[Service]
ExecStart=
ExecStart=-/usr/sbin/agetty --autologin streamer --noclear %I \$TERM
EOF

systemctl enable getty@tty99.service

echo "=== Installing Gamescope session for controller-friendly login ==="
rpm-ostree install gamescope-session

echo "=== Creating autostart entries for streamer ==="
sudo -u streamer mkdir -p /home/streamer/.config/autostart

cat >/home/streamer/.config/autostart/gamescope.desktop <<EOF
[Desktop Entry]
Type=Application
Exec=gamescope -f --steam
Hidden=false
Name=Gamescope Session
EOF

cat >/home/streamer/.config/autostart/steam.desktop <<EOF
[Desktop Entry]
Type=Application
Exec=steam -tenfoot
Hidden=false
Name=Steam Big Picture
EOF

chown -R streamer:streamer /home/streamer/.config/autostart

echo "=== Creating Sunshine disconnect cleanup hook ==="
cat >/usr/local/bin/sunshine-cleanup.sh <<EOF
#!/bin/bash
if ! pgrep -f sunshine | grep -v \$\$ > /dev/null; then
    systemctl stop sunshine-xorg
fi
EOF

chmod +x /usr/local/bin/sunshine-cleanup.sh

sudo -u streamer cat >/home/streamer/.config/sunshine/disconnect.sh <<EOF
#!/bin/bash
/usr/local/bin/sunshine-cleanup.sh
EOF

chmod +x /home/streamer/.config/sunshine/disconnect.sh
chown streamer:streamer /home/streamer/.config/sunshine/disconnect.sh

echo "=============================================="
echo "🎉 Setup Complete!"
echo "REBOOT NOW to activate VKMS, Xorg, and Sunshine."
echo "After reboot, connect via Moonlight — resolutions will auto-adapt."
echo "=============================================="
