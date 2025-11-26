# sunshine-bazzite-script
Scripts to get an Sunshine setup running on Bazzite with a virtual display.

## Scripts
- `virtual_display_setup.sh` — build and install a custom EDID RPM. Prompts for your EDID `.bin`, layers prerequisites if needed, patches initramfs, and appends the kernel arg.
- `virtual_display_update.sh` — update the EDID RPM in place. Detects the installed `edid_patch` name from `rpm-ostree status`, prompts for a new EDID `.bin`, rebuilds, and reinstalls.
- `virtual_display_uninstall.sh` — remove the EDID patch. Detects/removes the `edid_patch` RPM, deletes the dracut config, removes any `drm.edid_firmware=edid/...` karg, disables the custom initramfs, and reboots.

## Requirements
- Bazzite with `rpm-ostree`
- Root privileges (writes to `/etc`, manages systemd, installs layered packages)
- An EDID binary file to feed the scripts

## Usage (EDID)
1) Run `sudo ./virtual_display_setup.sh` and supply your EDID `.bin` path when prompted. The script builds/installs `edid_patch`, updates initramfs, and appends the kernel arg, then reboots.
2) To swap to a new EDID later, run `sudo ./virtual_display_update.sh`, provide the new `.bin`, and reboot when prompted.
3) To remove the EDID patch, run `sudo ./virtual_display_uninstall.sh` and reboot.

## Example EDID
The provided example_edid.bin supports various resolutions including 4k@60, 2420x1668@120Hz (iPad Pro), and 1280x800@90hz, amongst other more standard resolutions.

## Credits
https://www.reddit.com/r/Bazzite/comments/1gajkpg/add_a_custom_resolution/  
/u/Acru_Jovian  
https://gist.github.com/iamthenuggetman/6d0884954653940596d463a48b2f459c  
https://www.azdanov.dev/articles/2025/how-to-create-a-virtual-display-for-sunshine-on-arch-linux
