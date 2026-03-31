
# eos-webcam-utility-for-linux

**Automatisierte Pipeline zur Integration von Canon EOS DSLR-Hardware als V4L2-Loopback-Device unter Linux.**

Entwickelt von **[@jorisjanke](https://github.com/jorisjanke)** (Follow on [Instagram](https://instagram.com/jorisjanke))

Dieses Repository implementiert eine event-gesteuerte Automatisierungslösung, um Canon EOS Kameras (getestet mit EOS 2000D) als virtuelle Video-Schnittstelle zu registrieren. Das Setup nutzt `udev` zur Hardware-Erkennung und `systemd` zur Prozesssteuerung. Optimiert für **Arch Linux** und verifiziert unter **CachyOS**.


---

## 1. Problemstellung

Die Nutzung von Canon EOS DSLR-Hardware als Web-Interface unter **Arch Linux** und derivativen Distributionen wie **CachyOS** ist durch eine mangelnde native Herstellerunterstützung eingeschränkt. Während für Windows und macOS das proprietäre **"EOS Webcam Utility"** zur Verfügung steht, existiert unter Linux keine vergleichbare Plug-and-Play-Lösung. 

Bestehende Open-Source-Workarounds via `gphoto2` weisen in der Standardkonfiguration signifikante Defizite auf:
* **Ressourcen-Konflikte:** Der `gvfs-gphoto2-volume-monitor` belegt das PTP-Interface der Kamera unmittelbar nach der Hardware-Initialisierung exklusiv, was den Zugriff für Video-Applikationen blockiert.
* **Mangelnde Automatisierung:** Es fehlt eine systemseitige Integration, die den Stream-Prozess (De-Kodierung und V4L2-Mapping) beim Einschalten der Hardware automatisch instanziiert.
* **Persistenz:** Manuelle Terminal-Sessions sind instabil und bieten keine automatische Wiederherstellung der Verbindung (Self-Healing) bei Signalverlust oder Hardware-Reset.

Dieses Projekt schließt diese Lücke durch eine automatisierte Pipeline, die das Windows-Nutzungserlebnis auf Arch-basierte Systeme überträgt.

---

## 1. Architektur und Funktionsweise

Die Implementierung adressiert das Problem der exklusiven USB-Ressourcenbelegung unter Linux (z.B. durch `gvfs-gphoto2-volume-monitor`). Durch eine Kombination aus Kernel-Events und User-Space-Daemons wird folgende Pipeline etabliert:

1.  **Hardware-Trigger:** Beim Einschalten der Hardware erkennt der Kernel die Änderung am USB-Bus.
2.  **Event-Handling:** Eine `udev-rule` identifiziert das Gerät anhand von `VendorID` und `ProductID` und instanziiert eine `systemd-user-unit`.
3.  **Resource-Liberation:** Vor dem Stream-Start werden konkurrierende Prozesse (Gvfs/PTP-Monitore) terminiert, um den Zugriff auf das PTP-Interface zu ermöglichen.
4.  **V4L2-Sink:** `gphoto2` liest den LiveView-Payload via USB aus, der mittels `ffmpeg` dekodiert und in ein `v4l2loopback`-Device gemappt wird.

### Hardware-Voraussetzung
Für den stationären Betrieb ist eine unterbrechungsfreie Stromversorgung zwingend erforderlich. 
- **Komponente:** AC-Adapter mit DC-Koppler (Dummy-Batterie).
- **Referenz:** [vhbw Netzteil (Canon kompatibel)](https://www.amazon.de/vhbw-Netzteil-kompatibel-Kamera-Digitalkamera-schwarz/dp/B07CZ3RVYJ).

---

## 2. Installationsanleitung

### Schritt 1: Abhängigkeiten auflösen
Installieren Sie die notwendigen Pakete über den Paketmanager `pacman`:

```bash
sudo pacman -S gphoto2 ffmpeg v4l2loopback-utils libgphoto2
```

### Schritt 2: Kernel-Modul Konfiguration (v4l2loopback)
Das Modul `v4l2loopback` muss mit spezifischen Parametern geladen werden, um Kompatibilität mit Chromium-basierten Anwendungen und OBS zu gewährleisten.

1.  **Modul-Autoload:** Erstellen Sie `/etc/modules-load.d/v4l2loopback.conf`:
    ```text
    v4l2loopback
    ```
2.  **Modul-Parameter:** Erstellen Sie `/etc/modprobe.d/v4l2loopback.conf`:
    ```text
    options v4l2loopback exclusive_caps=1 card_label="Canon-Webcam"
    ```
    *Hinweis: Ein Reload via `sudo modprobe v4l2loopback` ist nach der Konfiguration erforderlich.*

### Schritt 3: Identifikation der USB-Hardware-Kennungen
Ermitteln Sie die Hardware-Identifier auf dem USB-Bus:
1.  Kamera via USB verbinden und einschalten.
2.  Ausführung von `lsusb`.
3.  Identifizieren Sie den Eintrag (Beispiel: `ID 04a9:32e1 Canon, Inc.`).
    * `<VENDOR_ID>` entspricht `04a9`.
    * `<PRODUCT_ID>` entspricht `32e1`.

### Schritt 4: Deployment der Konfigurationsdateien

#### I. Stream-Skript (`eos-stream.sh`)
Platzieren Sie das Skript unter `<SCRIPTS_PATH>` (z.B. `~/.local/bin/eos-stream.sh`).

```bash
#!/bin/bash
# Orchestrierung des PTP-Streams zu V4L2

# Termination konkurrierender Gvfs-Instanzen
pkill -9 -f gphoto2 || true
if command -v gio &> /dev/null; then
    gio mount -s gphoto2 2>/dev/null || true
fi

sleep 1

# Initialisierung des Streams via gphoto2 und ffmpeg-Transcoding
/usr/bin/gphoto2 --stdout --capture-movie --reset | \
/usr/bin/ffmpeg -i - -vcodec rawvideo -pix_fmt yuv420p -threads 0 -f v4l2 <VIDEO_DEVICE_PATH>
```
*Berechtigungen setzen:* `chmod +x <SCRIPTS_PATH>/eos-stream.sh`

#### II. Systemd User-Unit (`eos-webcam.service`)
Platzieren Sie die Unit unter `~/.config/systemd/user/eos-webcam.service`.

```ini
[Unit]
Description=Canon EOS Webcam Stream Daemon
After=graphical-session.target

[Service]
Type=simple
# %h expandiert zum User-Home-Verzeichnis
ExecStart=/usr/bin/bash %h/<RELATIVE_PATH_TO_SCRIPT>/eos-stream.sh
Restart=always
RestartSec=3

[Install]
WantedBy=default.target
```

#### III. Udev-Rule (`99-canon-webcam.rules`)
Platzieren Sie die Regel unter `/etc/udev/rules.d/99-canon-webcam.rules`.

```text
# Device-Aktivierung (Add/Bind)
SUBSYSTEM=="usb", ATTR{idVendor}=="<VENDOR_ID>", ATTR{idProduct}=="<PRODUCT_ID>", ACTION=="add|bind", TAG+="systemd", ENV{SYSTEMD_USER_WANTS}="eos-webcam.service"

# Device-Deaktivierung (Remove)
SUBSYSTEM=="usb", ATTR{idVendor}=="<VENDOR_ID>", ATTR{idProduct}=="<PRODUCT_ID>", ACTION=="remove", RUN+="/usr/bin/systemctl --user stop eos-webcam.service"

# Zugriffsberechtigungen für User-Space-Treiber (0666)
SUBSYSTEM=="usb", ATTR{idVendor}=="<VENDOR_ID>", ATTR{idProduct}=="<PRODUCT_ID>", MODE="0666"
```

---

## 3. Inbetriebnahme und Validierung

Nach der Platzierung der Dateien muss das System die neuen Konfigurationen einlesen:

```bash
# Udev-Regelsatz neu laden
sudo udevadm control --reload-rules && sudo udevadm trigger

# Systemd User-Daemon persistieren
systemctl --user daemon-reload
systemctl --user enable eos-webcam.service
```

### Monitoring
Zur Überprüfung der Funktionalität kann das Log der Systemd-Unit überwacht werden:
```bash
journalctl --user -u eos-webcam.service -f
```

---

## 🛠️ Mitwirkung und Credits
Das Projekt wurde initiiert von **@jorisjanke**. 

Technische Assistenz bei der Optimierung der `udev`-to-`systemd` Brücke sowie der Implementierung der Self-Healing-Logik (Reset-Zyklen des USB-Ports) erfolgte durch **Gemini 3 Flash (Google DeepMind)**. 

---
**Links:** [GitHub Repository](https://github.com/jorisjanke/eos-webcam-utility-for-linux) | [Instagram](https://instagram.com/jorisjanke)
