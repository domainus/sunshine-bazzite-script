#!/usr/bin/env bash
set -euo pipefail

kscreen-doctor \
        output.DP-1.enable \
        output.DP-2.enable \
        output.DP-2.priority.1 \
        output.DP-3.disable
