#!/bin/bash
# Canon EOS Webcam Utility for Linux
# Author: @jorisjanke (GitHub/Instagram)

# Kill potentially blocking processes (gvfs/gphoto)
pkill -9 -f gphoto2 || true
if command -v gio &> /dev/null; then
    gio mount -s gphoto2 2>/dev/null || true
fi

# Short delay to let the USB bus settle
sleep 1

# Auto-detect the first available video loopback device
VIDEO_DEV=$(ls /dev/video* | head -n 1)

# Start the stream
# Using --reset to ensure the PTP interface is fresh
/usr/bin/gphoto2 --stdout --capture-movie --reset | \
/usr/bin/ffmpeg -i - -vcodec rawvideo -pix_fmt yuv420p -threads 0 -f v4l2 "$VIDEO_DEV"
