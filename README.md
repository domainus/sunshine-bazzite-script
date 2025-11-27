# sunshine-bazzite-script
Scripts to get a Sunshine setup running on Bazzite with a virtual display (custom EDID + headless VKMS).

## Scripts
- `virtual_display_setup.sh` — build and install a custom EDID RPM. Prompts for your EDID `.bin`, layers prerequisites if needed, patches initramfs, and appends the kernel arg.
- `virtual_display_update.sh` — update the EDID RPM in place. Detects the installed `edid_patch` name from `rpm-ostree status`, prompts for a new EDID `.bin`, rebuilds, and reinstalls.
- `virtual_display_uninstall.sh` — remove the EDID patch. Detects/removes the `edid_patch` RPM, deletes the dracut config, removes any `drm.edid_firmware=edid/...` karg, disables the custom initramfs, and reboots.
- `setup_sunshine_scripts.sh` — installs the Sunshine prep/cleanup scripts to `~/.local/bin` and writes `global_prep_cmd` to `~/.config/sunshine.conf`.
- `sunshine_sleep.sh` / `sunshine_cancel_sleep.sh` — start/stop a per-user 60s suspend timer without sudo. Called by the prep/undo scripts.

## Requirements
- Bazzite with `rpm-ostree`
- Root privileges (writes to `/etc`, manages systemd, installs layered packages)
- An EDID binary file to feed the scripts

## Usage (EDID)

### Prerequisite Steps
1) Clone this repo.
2) Run `ujust setup-sunshine` if not done already. 
3) Run `for p in /sys/class/drm/*/status; do con=${p%/status}; echo -n "${con#*/card?-}: "; cat $p; done` to find a list of GPUs' free DP or HDMI output.
4) Update references in the `virtual_display_setup.sh`, `sunshine_do.sh` and `sunshine_undo.sh` based on the results of the prior command.

### Installation
0) Kill the Sunshine Process
1) Run `sudo ./virtual_display_setup.sh` and supply your EDID `.bin` path when prompted. The script builds/installs `edid_patch`, updates initramfs, and appends the kernel arg, then reboots.
2) Run `sudo ./setup_sunshine_scripts.sh`. This installs the Sunshine prep/cleanup scripts to `~/.local/bin` and writes `~/.config/sunshine.conf` with:
```
global_prep_cmd = [{"do":"bash -c \"${HOME}/.local/bin/sunshine-do.sh \\\"${SUNSHINE_CLIENT_WIDTH}\\\" \\\"${SUNSHINE_CLIENT_HEIGHT}\\\" \\\"${SUNSHINE_CLIENT_FPS}\\\" \\\"${SUNSHINE_CLIENT_HDR}\\\"\"","undo":"bash -c \"${HOME}/.local/bin/sunshine-undo.sh\""}]
```
3) Restart Sunshine.

Notes:
- The sleep helper scripts do not need sudo. They use per-user state under `${XDG_RUNTIME_DIR:-/tmp}` and `loginctl`/`systemctl` to suspend.
- If you run them directly from the repo, ensure they are executable (`chmod +x sunshine_sleep.sh sunshine_cancel_sleep.sh`). The setup script handles this for the installed copies.

### Optional but HIGHLY RECOMMENDED
Run `setup_startup_failsafe_service.sh`. This makes it to where it runs the `sunshine_undo.sh` script on startup in the event that when connecting to Sunshine only the `sunshine_do.sh` script runs. This can help fix black screens after logging in. (Ask me how I know :] )

### Update edid_patch
1) To swap to a new EDID later, run `sudo ./virtual_display_update.sh`, provide the new `.bin`, and reboot when prompted.

### Uninstall
1) To remove the EDID patch, run `sudo ./virtual_display_uninstall.sh` and reboot.

## Example EDID
The provided example_edid.bin supports various resolutions including 4K@60, 2420x1668@120Hz (iPad Pro), and 1280x800@90Hz, among other common resolutions.

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

## Steam Big Picture Lag Fix
```
From /u/psirrow:

If you're still having the problem (or for anyone else who finds this post), I had the same issue but I solved it by ticking a few more settings. This is what I have:

in "Settings/Display" I have:

    "Disable GPU Blocklist" on

in "Settings/Interface" I have:

    "Enable smooth scrolling in web views" on (may not be necessary)

    "Enable GPU accelerated rendering in web views" on

    "Enable hardware video decoding, if supported" on
```

## Credits
https://www.reddit.com/r/Bazzite/comments/1gajkpg/add_a_custom_resolution/  
/u/Acru_Jovian  
https://gist.github.com/iamthenuggetman/6d0884954653940596d463a48b2f459c  
https://www.azdanov.dev/articles/2025/how-to-create-a-virtual-display-for-sunshine-on-arch-linux
https://www.reddit.com/r/linux_gaming/comments/1h2o0re/comment/mtq730l/
https://chatgpt.com/c/69273fd1-db30-8325-8cb6-8e881914c7d8