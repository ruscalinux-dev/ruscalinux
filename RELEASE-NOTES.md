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
  home folder, lists everything it does and does not do, and is now
  translated into 15 languages, with a user manual in English and Italian.
- **One look for the in-house tools.** RuscaCleaner, RuscaHub and RuscaMark
  are now native GNOME (libadwaita) applications in the RuscaLinux plum and
  pink colours. They follow the system light or dark style, share the same
  About window and keyboard shortcuts, and RuscaHub asks before deleting an
  AppImage and moves it to the trash. RuscaMark's app ID is now
  `org.ruscalinux.RuscaMark`: if you pinned it to the dash, pin it again.
- **Local AI tools.** RuscaLLama (chat) and RuscaTranslator (translation of
  Markdown documents, with Italian ↔ English linguistic knowledge) run
  language models on your own computer through ruscallama-engine, a build of
  llama.cpp. Nothing is sent over the internet; models are not included:
  copy a GGUF file into `~/.local/share/ruscallama/models/`.
- **SMPlayer** replaces VLC as the video player.
- **Python virtual environments** work out of the box: `python3 -m venv`.
- New boot splash.
- Removed: RuscaWriter and the uBlock Origin extension for Firefox.

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
