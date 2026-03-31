#!/bin/bash
# ==========================================
# Canon EOS Webcam Utility for Linux
# Author: @jorisjanke (GitHub/Instagram)
# ==========================================

# 1. Beende blockierende Prozesse (Gvfs/Gphoto)
# Viele Linux-Desktops mounten die Kamera automatisch als Laufwerk.
# Das verhindert, dass wir den Video-Stream abgreifen können.
pkill -9 -f gphoto2 || true
if command -v gio &> /dev/null; then
    # Versuche den spezifischen Mount der Kamera auszuhängen
    gio mount -s gphoto2 2>/dev/null || true
fi

# 2. Kurze Pause für den USB-Bus
sleep 1

# 3. Der Stream-Befehl
# --reset sorgt dafür, dass die PTP-Schnittstelle der Kamera frisch initialisiert wird.
/usr/bin/gphoto2 --stdout --capture-movie --reset | \
/usr/bin/ffmpeg -i - -vcodec rawvideo -pix_fmt yuv420p -threads 0 -f v4l2 <VIDEO_DEVICE_PATH>
