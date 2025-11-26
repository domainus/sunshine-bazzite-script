# sunshine-bazzite-script
Scripts to get a Sunshine setup running on Bazzite with a virtual display.

## Scripts
- `virtual_display_setup.sh` — build and install a custom EDID RPM. Prompts for your EDID `.bin`, layers prerequisites if needed, patches initramfs, and appends the kernel arg.
- `virtual_display_update.sh` — update the EDID RPM in place. Detects the installed `edid_patch` name from `rpm-ostree status`, prompts for a new EDID `.bin`, rebuilds, and reinstalls.
- `virtual_display_uninstall.sh` — remove the EDID patch. Detects/removes the `edid_patch` RPM, deletes the dracut config, removes any `drm.edid_firmware=edid/...` karg, disables the custom initramfs, and reboots.

## Requirements
- Bazzite with `rpm-ostree`
- Root privileges (writes to `/etc`, manages systemd, installs layered packages)
- An EDID binary file to feed the scripts

## Usage (EDID)

### Prerequisite Steps
1) Run `for p in /sys/class/drm/*/status; do con=${p%/status}; echo -n "${con#*/card?-}: "; cat $p; done` to find a list of GPUs' free DP or HDMI output.
2) Update references in the `virtual_display_setup.sh`, `sunshine_do.sh` and `sunshine_undo.sh` based on the results of the prior command.

### Installation
1) Clone this repo.
2) Run `sudo ./virtual_display_setup.sh` and supply your EDID `.bin` path when prompted. The script builds/installs `edid_patch`, updates initramfs, and appends the kernel arg, then reboots.
3) Run `sudo ./move_sunshine_scripts.sh`. This will move the `sunshine_do.sh` and `sunshine_undo.sh` to `~/.local/bin`. This will also update `~/.config/sunshine.conf` with the following:
`global_prep_cmd = [{"do":"bash -c \"${HOME}/.local/bin/sunshine-do.sh \\\"${SUNSHINE_CLIENT_WIDTH}\\\" \\\"${SUNSHINE_CLIENT_HEIGHT}\\\" \\\"${SUNSHINE_CLIENT_FPS}\\\" \\\"${SUNSHINE_CLIENT_HDR}\\\"\"","undo":"bash -c \"${HOME}/.local/bin/sunshine-undo.sh\""}`

### Update edid_patch
1) To swap to a new EDID later, run `sudo ./virtual_display_update.sh`, provide the new `.bin`, and reboot when prompted.

### Uninstall
1) To remove the EDID patch, run `sudo ./virtual_display_uninstall.sh` and reboot.

## Example EDID
The provided example_edid.bin supports various resolutions including 4K@60, 2420x1668@120Hz (iPad Pro), and 1280x800@90Hz, amongst other more standard resolutions.

## Custom EDIDs
The `samsung-q800t-hdmi2.1` EDID from [v4l-utils](https://git.linuxtv.org/v4l-utils.git/tree/utils/edid-decode/data). Use [Custom Resolution Utility (CRU)](https://customresolutionutility.net/) to add more resolutions to the base EDID and export. CRU works fine under Wine.

## Default Steam Launch Commands
`LD_PRELOAD=""
PROTON_HIDE_NVIDIA_GPU=0 
PROTON_ENABLE_NVAPI=1 
gamescope -f -b 
    -H $(kscreen-doctor -j | jq '.screen.currentSize.height') 
    --hdr-enabled 
    --adaptive-sync 
    -- %command%
`

## Credits
https://www.reddit.com/r/Bazzite/comments/1gajkpg/add_a_custom_resolution/  
/u/Acru_Jovian  
https://gist.github.com/iamthenuggetman/6d0884954653940596d463a48b2f459c  
https://www.azdanov.dev/articles/2025/how-to-create-a-virtual-display-for-sunshine-on-arch-linux
https://www.reddit.com/r/linux_gaming/comments/1h2o0re/comment/mtq730l/
