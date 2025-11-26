#!/bin/bash
set -e

# Get params and set any defaults
width=${1:-3840}
height=${2:-2160}
fps=${3:-120}
hdr=${4:-"false"}

hdr_args=()
if [[ "$hdr" == "true" ]]; then
        hdr_args+=( "output.HDMI-A-2.hdr.enable" )
        hdr_args+=( "output.HDMI-A-2.wcg.enable" )
else
        hdr_args+=( "output.HDMI-A-2.hdr.disable" )
fi

kscreen-doctor \
        output.HDMI-A-2.enable \
        output.HDMI-A-2.priority.1 \
        output.HDMI-A-2.mode.${width}x${height}@${fps} \
        "${hdr_args[@]}" \
        output.DP-1.disable