# RuscaLinux @VERSION@

<!--
  Template. @VERSION@, @SUITE@, @ARCH@, @KERNEL@, @DESKTOP@, @ISO@, @SHA256@,
  @SIZE@ and @DATE@ are filled in by build.sh from release.conf and the
  image that was actually built. Edit the prose below for each release;
  never type the version, the file name or the checksum by hand.
-->

> **@VERSION@ is a stable release.** The project uses a `.99` minor to mark a
> stable milestone — it is not a beta or a pre-release.

## Highlights

<!-- Rewrite this section for each release. Everything else is automatic. -->

- **RuscaMark**, a new Markdown editor: formatting appears as you type, the
  page stays centred like a sheet of paper, and spelling is checked live.
- **RuscaHub**, a new AppImage manager: import an AppImage by drag and drop,
  add it to the GNOME menu with its original icon, run it or remove it.
- **RuscaCleaner** has been rewritten. It removes activity traces from the
  home folder, lists everything it does and does not do, and has a user
  manual in English and Italian.
- **One look for the in-house tools.** RuscaCleaner, RuscaHub and RuscaMark
  are now native GNOME (libadwaita) applications in the RuscaLinux plum and
  pink colours. They follow the system light or dark style, share the same
  About window and keyboard shortcuts, and RuscaHub asks before deleting an
  AppImage and moves it to the trash. RuscaMark's app ID is now
  `org.ruscalinux.RuscaMark`: if you pinned it to the dash, pin it again.
- **RuscaWriter joins the in-house tools.** The book-writing program
  (chapters, notes, Markdown, typesetting and export to PDF, EPUB, ODT,
  DOCX…) now has the same GNOME look as the other tools, page themes with
  verified contrast, and opens `.rwr` projects with a double click.
- **26 languages everywhere.** All in-house tools follow the system language
  and are translated into the same 26 languages, now including Traditional
  Chinese and European Portuguese.
- **Local AI tools.** RuscaLLama (chat) and RuscaTranslator run language
  models on your own computer. RuscaTranslator translates Markdown documents
  between all 26 languages, with Italian ↔ English linguistic knowledge, and
  detects the source language on its own, telling apart close variants
  (Ukrainian and Russian, Simplified and Traditional Chinese, European and
  Brazilian Portuguese). Models are not included: copy a GGUF file into
  `~/.local/share/ruscallama/models/`.
- **ruscallama-engine** is llama.cpp 0.8.0, the latest stable release, built
  from source with Vulkan for NVIDIA, AMD and Intel graphics. It is built
  without HTTPS support and without its web interface, so it cannot download
  anything: nothing is sent over the internet.
- **SMPlayer** replaces VLC as the video player.
- **Python virtual environments** work out of the box: `python3 -m venv`.
- **Larger text in the graphical installer.** Text now scales with the
  screen, so the installer is just as readable on a 4K monitor as on a
  Full HD one. To choose the size yourself, add `ruscalinux.dpi=150` (or any
  value from 72 to 384) to the installer's boot line.
- New boot splash.
- Removed: the uBlock Origin extension for Firefox.

## The image

| | |
|---|---|
| **File** | `@ISO@` |
| **Size** | @SIZE@ |
| **SHA256** | `@SHA256@` |
| **Base** | Debian @SUITE@, @ARCH@ |
| **Desktop** | @DESKTOP@ |
| **Kernel** | Linux @KERNEL@ |
| **Released** | @DATE@ |

Hybrid ISO: a full live system plus its own installer, including a
speech-synthesis option for accessibility. Write it byte-for-byte to a USB
stick of 4 GB or larger.

Download: <https://sourceforge.net/projects/ruscalinux/files/@VERSION@/>

Verify before writing:

```sh
sha256sum @ISO@
sha256sum -c SHA256SUMS
```

## Build it yourself

```sh
sudo apt install live-build
./build.sh
```

The version of the image lives in `release.conf`. Each utility in `tools/`
carries the same version in its own `make-deb.sh`; `make-debs.sh` warns if
they differ.

## Licensing

Build scripts and original design sources: GPL-3.0. Third-party material keeps
its own licence. The name *RuscaLinux*, its logo and its emblem are not covered
by the GPL — see `TRADEMARK.md`.
