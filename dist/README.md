# RuscaLinux

> *Free, complete, and ready to go.*

A desktop Linux distribution based on Debian stable. Multilingual, complete with
office and multimedia software, refined in detail — a finished desktop the
moment it boots.

**Latest release:** @VERSION@ (@ARCH@)
**Website:** https://www.ruscalinux.org
**YouTube:** https://www.youtube.com/@ruscalinux
**Contact:** info@ruscalinux.org

---

## What's inside RuscaLinux @VERSION@

- **Base** — Debian 13 stable, Linux 6.12 long-term kernel
- **Desktop** — GNOME 48.7 on Wayland with custom Adwaita-Prugna icons and Plymouth boot splash
- **Office** — LibreOffice 25.2 (Writer, Calc, Impress, Draw, Math, Base), RuscaWriter, Evince
- **Multimedia** — VLC, Audacity, OBS Studio, GIMP 3.0, Audacious, Brasero, EasyTAG, FFmpeg 7.1
- **Internet** — Firefox ESR 140, Thunderbird 140, qBittorrent
- **Languages** — 40+ localizations bundled in the base image
- **In-house tools** — RuscaWriter (distraction-free writing, PDF and EPUB export), RuscaCleaner (system cleanup)
- **Security** — AppArmor mandatory access control enabled by default
- **Image** — hybrid ISO with live system + installer (including speech-synthesis option)
- **Total** — @PACCHETTI@ carefully selected packages

---

## Files in this release

| File | Purpose |
|------|---------|
| `@ISO@` | The system image (live + installer) |
| `SHA256SUMS` | Official SHA256 checksum for verification |
| `ruscalinux-@VERSION@-@ARCH@.packages` | Full list of installed packages with versions |

---

## Verify your download

After downloading, always verify the ISO against the official SHA256 checksum.
If even one character differs, do not use the file.

**Expected hash for @VERSION@:**

```
@SHA256@
```

**On Linux or macOS:**

```sh
sha256sum @ISO@
sha256sum -c SHA256SUMS
```

**On Windows (PowerShell):**

```powershell
Get-FileHash @ISO@ -Algorithm SHA256
```

---

## Write to a USB stick

The image is hybrid, so it can be written byte-for-byte to a USB drive
(4 GB or larger).

**Graphical tools** — balenaEtcher (Windows/macOS/Linux) or GNOME Disks (Linux):
pick the ISO, pick the drive, flash.

**Command line (Linux / macOS):**

```sh
sudo dd if=@ISO@ of=/dev/sdX bs=4M status=progress oflag=sync
```

Replace `/dev/sdX` with your USB device. **Double-check the target** —
`dd` overwrites it completely.

---

## Try & install

Boot from the USB stick and choose:

- **Live system (@ARCH@)** — explore RuscaLinux without touching your disk
- **Start installer** — install to your drive
- **Start installer with speech synthesis** — accessible, spoken installation

---

## A note on updates

RuscaLinux ships with **no live repositories**. Your system stays exactly as you
installed and tested it — no nightly churn, no surprise breakages. To move
forward, you download a new ISO and install it fresh. Stability here is a
deliberate feature.

---

## Documentation, screenshots, FAQ

Everything is on the project website:
**https://www.ruscalinux.org**

For news and walkthroughs, see the YouTube channel:
**https://www.youtube.com/@ruscalinux**

For questions, bug reports, or feedback:
**info@ruscalinux.org**

---

## Licensing

RuscaLinux is a free and open-source aggregate built from packages released
under several free software licenses (mainly GPL, LGPL, MIT, BSD, MPL, Apache).
Each component retains its original license. See `INSTALL.md` and the website
for details.
