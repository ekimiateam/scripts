#!/bin/bash
for file in `ls -1 /sys/class/drm/*/edid`; do text=$(tr -d '\0' <"$file"); if [ -n "$text" ]; then edid-decode "$file" | grep -e Manufacturer: -e Product; sleep 0.0001; fi done
