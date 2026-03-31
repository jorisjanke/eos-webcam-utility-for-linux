---

## eos-webcam-utility-for-linux 📸 🐧

**Verwandle deine Canon EOS DSLR in eine vollautomatische High-End Webcam unter Linux – ohne manuelle Befehle.**

Erstellt von **[@jorisjanke](https://github.com/jorisjanke)** (Folge mir auf [Instagram](https://instagram.com/jorisjanke))

Dieses Repository bietet eine professionelle Plug-and-Play-Lösung für Canon-Kameras (optimiert für EOS 2000D). Dank der Kombination aus Kernel-Events (`udev`) und System-Diensten (`systemd`) startet dein Kamera-Stream vollautomatisch, sobald du die Hardware einschaltest.

---

## 📖 Hintergrund & Funktionsweise

Unter Windows gibt es das offizielle "EOS Webcam Utility". Linux-Nutzer mussten bisher oft komplexe Skripte manuell im Terminal starten. Dieses Projekt löst das Problem elegant:

1.  **Hardware-Power:** Um stundenlange Meetings oder Streams zu ermöglichen, nutzen wir ein Netzteil mit Dummy-Batterie.
    * **Empfohlenes Netzteil:** [vhbw Netzteil kompatibel mit Canon EOS](https://www.amazon.de/vhbw-Netzteil-kompatibel-Kamera-Digitalkamera-schwarz/dp/B07CZ3RVYJ)
2.  **Gvfs-Blocking:** Linux-Desktops (Gnome/KDE) versuchen oft, die Kamera als USB-Laufwerk zu mounten. Das blockiert den Zugriff für Video-Streams. Mein Skript "entreißt" dem System die Kamera aktiv, damit der Stream fließen kann.
3.  **Automatisierung:** Wir nutzen die USB-Events des Kernels. Schaltest du die Kamera an, wird ein Hintergrunddienst gestartet. Schaltest du sie aus, wird der Dienst sauber beendet.

---

## 🛠️ Vollständige Installationsanleitung

Befolge diese Schritte exakt, um dein System einzurichten.

### Schritt 1: Abhängigkeiten installieren
Zuerst benötigen wir die Treiber und Video-Tools. (Beispiel für Arch Linux/CachyOS):
```bash
sudo pacman -S gphoto2 ffmpeg v4l2loopback-utils libgphoto2
```

### Schritt 2: Das virtuelle Video-Gerät (v4l2loopback)
Wir müssen Linux sagen, dass es eine "virtuelle Webcam" erstellen soll.

1.  **Automatisches Laden beim Booten:**
    Erstelle die Datei `/etc/modules-load.d/v4l2loopback.conf`:
    ```text
    v4l2loopback
    ```
2.  **Konfiguration der Webcam:**
    Erstelle die Datei `/etc/modprobe.d/v4l2loopback.conf`:
    ```text
    options v4l2loopback exclusive_caps=1 card_label="Canon-Webcam"
    ```
    *Hinweis: Starte danach neu oder lade das Modul manuell mit `sudo modprobe v4l2loopback`.*

### Schritt 3: Deine Kamera-ID finden
Jede Kamera hat eine eindeutige Vendor- und Product-ID.
1.  Schließe die Kamera an und schalte sie ein.
2.  Gib im Terminal ein: `lsusb`
3.  Suche die Zeile deiner Canon (z.B. `ID 04a9:32e1 Canon, Inc.`).
    * `04a9` ist deine `<VENDOR_ID>`
    * `32e1` ist deine `<PRODUCT_ID>`

### Schritt 4: Die Dateien einrichten
Lade die Dateien aus diesem Repo herunter und passe die Platzhalter an.

#### 1. Das Stream-Skript (`eos-stream.sh`)
Speichere es unter `<PATH_TO_SCRIPT>` (z.B. `~/.local/bin/eos-stream.sh`).
```bash
#!/bin/bash
# Canon EOS Linux Stream Daemon by @jorisjanke

# 1. Kill blockierende Prozesse
pkill -9 -f gphoto2 || true
if command -v gio &> /dev/null; then
    gio mount -s gphoto2 2>/dev/null || true
fi

sleep 1

# 2. Start den Stream
# Ersetze <VIDEO_DEVICE> durch dein Gerät, meist /dev/video0
/usr/bin/gphoto2 --stdout --capture-movie --reset | \
/usr/bin/ffmpeg -i - -vcodec rawvideo -pix_fmt yuv420p -threads 0 -f v4l2 <VIDEO_DEVICE>
```
*Ausführbar machen:* `chmod +x <PATH_TO_SCRIPT>/eos-stream.sh`

#### 2. Der Systemd-Service (`eos-webcam.service`)
Speichere es unter `~/.config/systemd/user/eos-webcam.service`.
```ini
[Unit]
Description=Canon EOS Webcam Stream Daemon

[Service]
Type=simple
# %h wird automatisch zu deinem Home-Verzeichnis aufgelöst
ExecStart=/usr/bin/bash %h/<RELATIVE_PATH_TO_SCRIPT>/eos-stream.sh
Restart=always
RestartSec=3

[Install]
WantedBy=default.target
```

#### 3. Die udev-Regel (`99-canon-webcam.rules`)
Speichere es mit Root-Rechten unter `/etc/udev/rules.d/99-canon-webcam.rules`.
```text
# Start beim Einschalten
SUBSYSTEM=="usb", ATTR{idVendor}=="<VENDOR_ID>", ATTR{idProduct}=="<PRODUCT_ID>", ACTION=="add|bind", TAG+="systemd", ENV{SYSTEMD_USER_WANTS}="eos-webcam.service"

# Stop beim Ausschalten
SUBSYSTEM=="usb", ATTR{idVendor}=="<VENDOR_ID>", ATTR{idProduct}=="<PRODUCT_ID>", ACTION=="remove", RUN+="/usr/bin/systemctl --user stop eos-webcam.service"

# Berechtigungen für den User-Zugriff
SUBSYSTEM=="usb", ATTR{idVendor}=="<VENDOR_ID>", ATTR{idProduct}=="<PRODUCT_ID>", MODE="0666"
```

### Schritt 5: Aktivierung
Führe diese Befehle aus, um das System scharf zu schalten:
```bash
# udev Regeln neu laden
sudo udevadm control --reload-rules

# User-Dienste neu laden und aktivieren
systemctl --user daemon-reload
systemctl --user enable eos-webcam.service
```

---

## 🧪 Fehlersuche (Troubleshooting)
Wenn der Stream nicht startet, kannst du das Log in Echtzeit prüfen:
```bash
journalctl --user -u eos-webcam.service -f
```
Häufige Ursache: Die Kamera ist noch im "Wiedergabe-Modus". Schalte sie in den Foto-Modus (M, Av, Tv oder P).

---

## 🛠️ Credits & KI-Kollaboration
Dieses Projekt wurde von **@jorisjanke** entwickelt. 
Besonderer Dank geht an die KI **Gemini 3 Flash (Google DeepMind)**, die maßgeblich an der Erstellung der robusten Architektur beteiligt war:
- Entwicklung der **udev-to-systemd Bridge** für verzögerungsfreies Plug-and-Play.
- Optimierung der **FFmpeg-Parameter** für minimale Latenz.
- Implementierung der **Gvfs-Auto-Unlock** Logik zur Befreiung blockierter USB-Ports.

---
**Folge mir für mehr Linux & Tech Content:**
[GitHub](https://github.com/jorisjanke) | [Instagram](https://instagram.com/jorisjanke)

---

### Was du jetzt tun musst:
1.  Erstelle das Repository auf GitHub mit dem Namen `eos-webcam-utility-for-linux`.
2.  Kopiere diesen Text in die `README.md`.
3.  Erstelle die drei Dateien (`.sh`, `.service`, `.rules`) im Repo und ersetze die Platzhalter für deine eigene Nutzung, oder lasse sie für andere Nutzer als `<x>` stehen.
4.  Veröffentliche deinen Medium-Artikel und verlinke dieses Repo darin.

Viel Erfolg, **@jorisjanke**! Das wird ein super Release.
