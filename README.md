# sunshine-bazzite-script
Scripts to get an Apollo-like, controller-friendly Sunshine setup running on Bazzite with a headless VKMS display.

## What the setup script does
- Creates a `streamer` user (video/render/tty groups) for running Sunshine.
- Enables the VKMS kernel module and adds Xorg configuration for a headless display on `:99`.
- Installs the required immutable packages via `rpm-ostree` (Xorg server and gamescope-session).
- Creates and enables systemd units for headless Xorg (`sunshine-xorg.service`), Sunshine (`sunshine@streamer`), and autologin on `tty99`.
- Sets up Sunshine config for the `streamer` user and autostarts Gamescope + Steam Big Picture.

## Requirements
- Run on Bazzite with `rpm-ostree` available (script calls `rpm-ostree install` and `rpm-ostree kargs`).
- Root privileges (the script writes to `/etc`, creates users, and manages systemd services).
- Sunshine installed or available via `ujust setup-sunshines` (the script will call this if `sunshine` is missing).

## Usage
1. Run the setup script as root: `sudo ./sunshine_vkms_setup.sh`
2. Set a password for the `streamer` user when prompted.
3. Reboot after the script completes so VKMS, Xorg, and Sunshine start cleanly.
4. Connect via Moonlight/Sunshine; resolutions will adapt to the headless display.

## Notes
- A disconnect hook stops the headless Xorg service when Sunshine is not running.

## Uninstall
1. Run as root: `sudo ./sunshine_vkms_uninstall.sh`
2. The uninstaller stops/disables the headless Xorg, Sunshine, and autologin services; removes VKMS/Xorg configs and the `rd.driver.pre=vkms` karg; deletes the Sunshine cleanup hook; cleans the `streamer` user’s Sunshine/autostart files; and optionally removes the `streamer` user entirely.
3. Reboot afterward to fully drop VKMS/Xorg remnants. Layered packages installed via `rpm-ostree install` (e.g., Xorg server, gamescope-session) are left in place; remove them separately if desired.
