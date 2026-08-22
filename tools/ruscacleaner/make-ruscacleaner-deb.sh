#!/bin/bash
# ---------------------------------------------------------------------------
# RuscaLinux — build the ruscacleaner .deb package.
#
# Uso: ./make-ruscacleaner-deb.sh [versione]
#
# Sorgenti attesi accanto a questo script:
#   ruscacleaner.py    l'applicazione
#   lang/*.json      le traduzioni (una per lingua)
#   ruscacleaner.svg   l'icona (da cui vengono generati i PNG)
#   ruscacleaner.desktop
#   org.ruscalinux.RuscaCleaner.metainfo.xml
#
# Il pacchetto finisce nella directory corrente, esattamente come fanno
# make-icons-deb.sh e make-fonts-deb.sh: è make-debs.sh a invocarlo da
# dentro local/extra_debs/.
# ---------------------------------------------------------------------------
set -euo pipefail

# ── Identità RuscaLinux ─────────────────────────────────────────────────────
RL_VENDOR="RuscaLinux"
RL_MAINTAINER="ruscalinux-dev <info@ruscalinux.org>"
RL_HOMEPAGE="https://www.ruscalinux.org/ruscacleaner/"
RL_VERSION_SUFFIX="~ruscalinux1"
# ────────────────────────────────────────────────────────────────────────────

PACKAGE_NAME="ruscacleaner"
UPSTREAM_VERSION="${1:-1.0}"
VERSION="${UPSTREAM_VERSION}-1${RL_VERSION_SUFFIX}"
ARCH="all"

SRC="$(cd "$(dirname "$0")" && pwd)"
ORIGINAL_DIR="$(pwd)"

command -v dpkg-deb >/dev/null || { echo "dpkg-deb mancante: sudo apt install dpkg-dev"; exit 1; }

# I PNG vengono generati dall'SVG: senza rsvg-convert il pacchetto avrebbe
# solo l'icona scalable, e GNOME Shell la rasterizzerebbe male a 32px.
RSVG=""
if command -v rsvg-convert >/dev/null 2>&1; then
    RSVG="rsvg-convert"
elif command -v inkscape >/dev/null 2>&1; then
    RSVG="inkscape"
else
    echo "  ⚠ rsvg-convert mancante (sudo apt install librsvg2-bin):"
    echo "    il pacchetto conterrà solo l'icona SVG, senza i PNG."
fi

for f in ruscacleaner.py ruscacleaner.svg ruscacleaner.desktop; do
    [ -f "$SRC/$f" ] || { echo "Errore: $f non trovato in $SRC"; exit 1; }
done

echo "==> Vendor: $RL_VENDOR"
echo "==> Pacchetto: $PACKAGE_NAME $VERSION"

TEMP_DIR=$(mktemp -d)
BUILD_DIR="$TEMP_DIR/${PACKAGE_NAME}_${VERSION}_${ARCH}"
trap 'rm -rf "$TEMP_DIR"' EXIT

mkdir -p "$BUILD_DIR"/DEBIAN
mkdir -p "$BUILD_DIR"/usr/bin
mkdir -p "$BUILD_DIR"/usr/share/"$PACKAGE_NAME"/lang
mkdir -p "$BUILD_DIR"/usr/share/applications
mkdir -p "$BUILD_DIR"/usr/share/metainfo
mkdir -p "$BUILD_DIR"/usr/share/man/man1
mkdir -p "$BUILD_DIR"/usr/share/doc/"$PACKAGE_NAME"
mkdir -p "$BUILD_DIR"/usr/share/icons/hicolor/scalable/apps

# --- applicazione -----------------------------------------------------------
echo "==> Applicazione"
install -m 644 "$SRC/ruscacleaner.py" "$BUILD_DIR/usr/share/$PACKAGE_NAME/ruscacleaner.py"

# Traduzioni: il programma cerca lang/ accanto a se stesso.
LANGS=0
for f in "$SRC"/lang/*.json; do
    [ -e "$f" ] || continue
    install -m 644 "$f" "$BUILD_DIR/usr/share/$PACKAGE_NAME/lang/"
    LANGS=$((LANGS + 1))
done
[ "$LANGS" -gt 0 ] || { echo "Errore: nessun file in lang/ — serve almeno en.json"; exit 1; }
[ -f "$SRC/lang/en.json" ] || { echo "Errore: lang/en.json mancante (è il ripiego)"; exit 1; }
echo "    $LANGS lingue"

cat > "$BUILD_DIR/usr/bin/$PACKAGE_NAME" <<'LAUNCHER'
#!/bin/sh
exec python3 /usr/share/ruscacleaner/ruscacleaner.py "$@"
LAUNCHER
chmod 755 "$BUILD_DIR/usr/bin/$PACKAGE_NAME"

install -m 644 "$SRC/ruscacleaner.desktop" "$BUILD_DIR/usr/share/applications/"
[ -f "$SRC/org.ruscalinux.RuscaCleaner.metainfo.xml" ] && \
    install -m 644 "$SRC/org.ruscalinux.RuscaCleaner.metainfo.xml" "$BUILD_DIR/usr/share/metainfo/"

# --- icone ------------------------------------------------------------------
echo "==> Icone"
install -m 644 "$SRC/ruscacleaner.svg" \
    "$BUILD_DIR/usr/share/icons/hicolor/scalable/apps/$PACKAGE_NAME.svg"

if [ -n "$RSVG" ]; then
    for size in 16 22 24 32 48 64 128 256 512; do
        DEST="$BUILD_DIR/usr/share/icons/hicolor/${size}x${size}/apps"
        mkdir -p "$DEST"
        if [ "$RSVG" = "rsvg-convert" ]; then
            rsvg-convert -w "$size" -h "$size" \
                -o "$DEST/$PACKAGE_NAME.png" "$SRC/ruscacleaner.svg"
        else
            inkscape --export-type=png -w "$size" -h "$size" \
                -o "$DEST/$PACKAGE_NAME.png" "$SRC/ruscacleaner.svg" >/dev/null 2>&1
        fi
        chmod 644 "$DEST/$PACKAGE_NAME.png"
    done
fi

# --- documentazione ---------------------------------------------------------
echo "==> Documentazione"
cat > "$BUILD_DIR/usr/share/man/man1/$PACKAGE_NAME.1" <<MAN
.TH RUSCACLEANER 1 "$(date +%Y-%m-%d)" "RuscaCleaner ${UPSTREAM_VERSION}" "Comandi utente"
.SH NOME
ruscacleaner \- pulizia di miniature, file recenti e cronologia della shell
.SH SINTASSI
.B ruscacleaner
.SH DESCRIZIONE
.B RuscaCleaner
rimuove i dati che si accumulano con l'uso quotidiano del desktop: anteprime
di immagini e video, elenco dei documenti aperti di recente, cronologia di
bash e zsh, contenuto del cestino.
.PP
Ogni operazione è limitata alla cartella personale dell'utente che esegue il
programma e richiede una conferma esplicita. RuscaCleaner non va eseguito con
.BR sudo (8):
opererebbe sulla home di root.
.SH FILE
.TP
.I ~/.cache/thumbnails
Anteprime generate dal gestore file.
.TP
.I ~/.local/share/recently-used.xbel
Elenco dei documenti aperti di recente.
.TP
.I ~/.bash_history ", " ~/.zsh_history
Cronologia della shell.
.SH VEDERE ANCHE
.BR history (3)
.SH AUTORE
Progetto RuscaLinux \- ${RL_HOMEPAGE}
MAN
gzip -9n "$BUILD_DIR/usr/share/man/man1/$PACKAGE_NAME.1"

cat > "$BUILD_DIR/usr/share/doc/$PACKAGE_NAME/copyright" <<COPY
Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
Upstream-Name: RuscaCleaner
Upstream-Contact: ruscalinux-dev <info@ruscalinux.org>
Source: https://www.ruscalinux.org/ruscacleaner/

Files: *
Copyright: 2026 Nunzio Curcuruto <info@ruscalinux.org>
License: GPL-3+
 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
 .
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 .
 On Debian systems, the full text of the GNU General Public License
 version 3 can be found in the file /usr/share/common-licenses/GPL-3.
COPY

cat > "$TEMP_DIR/changelog.Debian" <<CHANGE
$PACKAGE_NAME ($VERSION) unstable; urgency=low

  * Versione $UPSTREAM_VERSION per RuscaLinux.

 -- $RL_MAINTAINER  $(date -R)
CHANGE
gzip -9nc "$TEMP_DIR/changelog.Debian" \
    > "$BUILD_DIR/usr/share/doc/$PACKAGE_NAME/changelog.Debian.gz"

# --- metadati del pacchetto -------------------------------------------------
cat > "$BUILD_DIR/DEBIAN/control" <<CONTROL
Package: $PACKAGE_NAME
Version: $VERSION
Section: utils
Priority: optional
Architecture: $ARCH
Depends: python3, python3-gi, gir1.2-gtk-4.0, gir1.2-adw-1
Vendor: $RL_VENDOR
Maintainer: $RL_MAINTAINER
Homepage: $RL_HOMEPAGE
Description: Cleaner for thumbnails, recent files and shell history
 RuscaCleaner removes the data that accumulates during everyday desktop use:
 image and video thumbnails, the list of recently opened documents, bash and
 zsh history, and the contents of the trash.
 .
 Every action is limited to the home directory of the user running it and is
 confirmed before it runs.
 .
 Part of the RuscaLinux project, a Debian-based GNU/Linux distribution.
CONTROL

cat > "$BUILD_DIR/DEBIAN/postinst" <<'POSTINST'
#!/bin/sh
set -e

if [ "$1" = "configure" ]; then
    if command -v gtk-update-icon-cache >/dev/null 2>&1; then
        gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor 2>/dev/null || true
    fi
    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database -q /usr/share/applications 2>/dev/null || true
    fi
fi

exit 0
POSTINST
chmod 755 "$BUILD_DIR/DEBIAN/postinst"

cat > "$BUILD_DIR/DEBIAN/postrm" <<'POSTRM'
#!/bin/sh
set -e

if [ "$1" = "remove" ] || [ "$1" = "purge" ]; then
    if command -v gtk-update-icon-cache >/dev/null 2>&1; then
        gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor 2>/dev/null || true
    fi
    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database -q /usr/share/applications 2>/dev/null || true
    fi
fi

exit 0
POSTRM
chmod 755 "$BUILD_DIR/DEBIAN/postrm"

find "$BUILD_DIR/usr" -type d -exec chmod 755 {} \;
find "$BUILD_DIR/usr/share" -type f -exec chmod 644 {} \;
chmod 755 "$BUILD_DIR/usr/bin/$PACKAGE_NAME"

INSTALLED_SIZE=$(du -sk "$BUILD_DIR/usr" | cut -f1)
echo "Installed-Size: $INSTALLED_SIZE" >> "$BUILD_DIR/DEBIAN/control"

# --- costruzione ------------------------------------------------------------
echo "==> Costruzione .deb"
cd "$TEMP_DIR"
dpkg-deb --build --root-owner-group "$BUILD_DIR" >/dev/null

DEB_FILE="${PACKAGE_NAME}_${VERSION}_${ARCH}.deb"
mv "${BUILD_DIR}.deb" "$ORIGINAL_DIR/$DEB_FILE"
cd "$ORIGINAL_DIR"

echo "✅ $DEB_FILE ($(du -h "$DEB_FILE" | cut -f1))"
