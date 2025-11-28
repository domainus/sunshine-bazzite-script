#!/usr/bin/env bash

# Wait a moment for GPU to initialize
sleep 1

# 1. Force DPMS on all outputs
kscreen-doctor output.DP-1.enable
kscreen-doctor output.DP-2.enable

# Switch VTs to force GPU redraw
chvt 3
sleep 0.3
chvt 1

# 2. Toggle DPMS to ensure displays get a proper signal
kscreen-doctor output.DP-1.dpms.off
kscreen-doctor output.DP-2.dpms.off
sleep 0.5
kscreen-doctor output.DP-1.dpms.on
kscreen-doctor output.DP-2.dpms.on

# OPTION: if you have specific monitors you want re-applied:
# kscreen-doctor output.HDMI-A-1.enable
# kscreen-doctor output.DisplayPort-0.enable
