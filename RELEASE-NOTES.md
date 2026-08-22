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

- **RuscaWriter** replaces Apostrophe as the distraction-free writing tool:
  justified PDF export with hyphenation, EPUB export, cover generator.
- **RuscaCleaner**, a new utility to clear caches, thumbnails and history.
- Guided partitioning is now automatic: choose the disk, confirm once, and
  the installer does the rest.
- ImageMagick's legacy `display` window no longer appears in the menu.

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

The version lives in `release.conf` and nowhere else.

## Licensing

Build scripts and original design sources: GPL-3.0. Third-party material keeps
its own licence. The name *RuscaLinux*, its logo and its emblem are not covered
by the GPL — see `TRADEMARK.md`.
