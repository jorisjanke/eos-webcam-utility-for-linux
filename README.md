# eos-webcam-utility-for-linux 📸 🐧

**Verwandle deine Canon EOS DSLR in eine vollautomatische High-End Webcam unter Linux.**

Erstellt von **[@jorisjanke](https://github.com/jorisjanke)** (Folge mir auf [Instagram](https://instagram.com/jorisjanke))

Dieses Repository enthält eine robuste Plug-and-Play-Lösung für Canon-Kameras (getestet mit EOS 2000D). Es automatisiert den gesamten Prozess vom Einschalten der Hardware bis zum fertigen Video-Feed in OBS, Discord oder Zoom.

---

## 📖 Die Hintergrundgeschichte & Prozess
Unter Windows gibt es das "EOS Webcam Utility". Unter Linux mussten Nutzer bisher oft komplexe Terminal-Befehle manuell eingeben. Mein Ziel war es, ein System zu schaffen, das **event-basiert** arbeitet: Kamera an = Stream startet. Kamera aus = Alles ruht.

### 1. Die Hardware (Unendlich Laufzeit)
Um nicht von Akkus abhängig zu sein, verwende ich ein Netzteil mit Dummy-Batterie. Das ist entscheidend für lange Streams oder Arbeitstage.
- **Mein Setup:** [vhbw Netzteil für Canon EOS](https://www.amazon.de/vhbw-Netzteil-kompatibel-Kamera-Digitalkamera-schwarz/dp/B07CZ3RVYJ)

### 2. Die Kamera-ID finden (Wichtig für udev)
Damit Linux weiß, auf welches Gerät es reagieren soll, müssen wir die USB-Kennung finden.
1. Schließe deine Kamera an und schalte sie ein.
2. Öffne ein Terminal und tippe: `lsusb`
3. Suche nach einer Zeile wie: `Bus 001 Device 011: ID 04a9:32e1 Canon, Inc...`
   - Hier ist `04a9` die **Vendor-ID** (`<VENDOR_ID>`)
   - Und `32e1` ist die **Product-ID** (`<PRODUCT_ID>`)

### 3. Das Problem mit Gvfs (Kamera belegt)
Linux-Desktops wie GNOME oder KDE versuchen oft, die Kamera als Speichermedium zu mounten. Das blockiert die Kamera für Video-Tools. Mein Skript löst dies durch `pkill` und `gio mount -s`, um die Kamera aktiv vom System "loszureißen", damit `gphoto2` sie übernehmen kann.

### 4. Der virtuelle Loopback
Wir nutzen `v4l2loopback`, um einen fiktiven Webcam-Kanal im System zu erstellen (`/dev/video0`). Dort hinein "schießt" FFmpeg das Bildmaterial der Kamera.

---

## 🚀 Installations-Anleitung

### Schritt 1: Abhängigkeiten
Installiere die notwendigen Pakete (Beispiel für Arch Linux):
```bash
sudo pacman -S gphoto2 ffmpeg v4l2loopback-utils
