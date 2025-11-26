echo "=== Installing Prequisites ==="
rpm-ostree install ruby-devel rubygems rpm-build
systemctl reboot
sudo gem install fpm

* Make and install the rpm package from the bin:
mkdir -p ~/edid_patch/usr/lib/firmware/edid
cp my_edid.bin ~/edid_patch/usr/lib/firmware/edid/
cd ~/edid_patch
fpm -s dir -t rpm -n edid_patch .
[Use 'ls' to find the exact name of the generated rpm file, as it can vary from the below]
rpm-ostree install edid_patch-1.0-1.x86_64.rpm

* Update initramfs:
echo 'install_items+=" /usr/lib/firmware/edid/my_edid.bin "' | sudo tee /etc/dracut.conf.d/99-local.conf
rpm-ostree initramfs --enable

* Add the kernel argument, then reboot
rpm-ostree kargs --append=drm.edid_firmware=edid/my_edid.bin
[You can also specify a specific output port such as HDMI-A-1:edid/my_edid.bin]
systemctl reboot