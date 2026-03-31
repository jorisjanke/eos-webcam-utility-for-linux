# eos-webcam-utility-for-linux 📸 🐧

**Automated High-Quality Webcam Setup for Canon EOS 2000D (and similar) on Linux.**

Created by **[@jorisjanke](https://github.com/jorisjanke)** (Follow on [Instagram](https://instagram.com/jorisjanke))

This utility provides a robust, "set-and-forget" solution to use your DSLR as a high-definition webcam. It replaces the missing official Canon EOS Utility on Linux with a seamless, event-driven architecture.

### 🌟 Key Features
- **Event-Driven:** No polling. The stream starts the millisecond you switch the camera to "ON".
- **Zero Resource Consumption:** Absolutely no CPU/RAM usage when the camera is powered off.
- **Self-Healing:** Automatically re-initializes the PTP connection if interrupted.
- **Infinite Power:** Optimized for use with external AC power adapters.

### 📖 Step-by-Step Guide
For a deep dive into the hardware (dummy batteries) and the software logic, check out my articles:
- **[Medium Article (English/German)](LINK_HERE)**

### 🚀 Quick Installation
1. **Dependencies:** `sudo pacman -S gphoto2 ffmpeg v4l2loopback-utils` (Arch) or equivalent.
2. **Setup v4l2loopback:** Ensure the module is loaded with `exclusive_caps=1`.
3. **Deploy:** Place `eos-stream.sh` in `~/.local/bin/` and the service in `~/.config/systemd/user/`.
4. **Permissions:** Copy the udev rule to `/etc/udev/rules.d/` and reload: `sudo udevadm control --reload-rules`.

---
*Credits: Parts of the error handling and systemd logic were refined with the help of **Gemini Pro (Google DeepMind)**.*
