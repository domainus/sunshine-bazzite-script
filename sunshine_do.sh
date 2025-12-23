#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# Get params and set any defaults
width=${1:-3840}
height=${2:-2160}
fps=${3:-120}
hdr=${4:-"false"}

hdr_args=()
if [[ "$hdr" == "true" ]]; then
        hdr_args+=( "output.DP-3.hdr.enable" )
        hdr_args+=( "output.DP-3.wcg.enable" )
else
        hdr_args+=( "output.DP-3.hdr.disable" )
fi

"${SCRIPT_DIR}/sunshine_cancel_sleep.sh"

"${SCRIPT_DIR}/unlock_on_connect.sh"

kscreen-doctor \
        output.DP-3.enable \
        output.DP-3.priority.1 \
        output.DP-3.mode.${width}x${height}@${fps} \
        "${hdr_args[@]}" \
        output.DP-1.disable \
        output.DP-2.disable

