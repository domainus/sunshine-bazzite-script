#!/usr/bin/env bash
set -euo pipefail

kscreen-doctor \
        output.DP-1.enable \
        output.DP-2.enable \
        output.DP-2.priority.1 \
        output.HDMI-A-1.disable
