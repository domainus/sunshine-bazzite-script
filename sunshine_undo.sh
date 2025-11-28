#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

"${SCRIPT_DIR}/sunshine_sleep.sh"
"${SCRIPT_DIR}/lock-streamer.sh"

kscreen-doctor \
        output.DP-1.enable \
        output.DP-2.enable \
        output.DP-2.priority.1 \
        output.HDMI-A-1.disable
