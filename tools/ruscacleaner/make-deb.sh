#!/usr/bin/env bash
# make-deb.sh — costruisce il pacchetto .deb di RuscaCleaner e il file SHA256SUMS
# Copyright (C) 2026  Nunzio Curcuruto — GNU GPL v3 o successiva
#
#   ./make-deb.sh            build-deb/ruscacleaner-ruscalinux_<versione>_<arch>.deb + SHA256SUMS
#   ./make-deb.sh --verify   verifica build-deb/SHA256SUMS
#   ./make-deb.sh --clean    rimuove build-deb/
set -euo pipefail

# ---- configurazione ---------------------------------------------------------
PKG_NAME="ruscacleaner"   # nome del pacchetto Debian e del programma
DEB_SUFFIX="ruscalinux"   # solo nel nome del file .deb
PKG_VERSION="1.99.2"
ARCH="${ARCH:-all}"        # Python puro: per le regole Debian l'architettura è "all"
MAINTAINER="Nunzio Curcuruto <info@ruscalinux.org>"
HOMEPAGE="https://ruscalinux.org/"
APP_ID="org.ruscalinux.RuscaCleaner"
LANGS=(en zh_CN es hi ar pt_BR ru ja de fr it ko id tr pl)
DOCS=(docs/MANUAL_en.md docs/MANUAL_it.md)

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="$SRC_DIR/build-deb"
STAGE="$OUT_DIR/staging"
DEB_FILE="${PKG_NAME}-${DEB_SUFFIX}_${PKG_VERSION}_${ARCH}.deb"
LIB_DIR="usr/lib/$PKG_NAME"
DOC_DIR="usr/share/doc/$PKG_NAME"

# Riproducibilità: un'unica data per changelog, file e archivio.
export SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-$(date +%s)}"
DATE_RFC="$(LC_ALL=C date -Ru -d "@$SOURCE_DATE_EPOCH")"

say() { printf '\n==> %s\n' "$*"; }
die() { echo "Errore: $*" >&2; exit 1; }

case "${1:-}" in
    --clean)  rm -rf "$OUT_DIR"; echo "Rimossa build-deb/."; exit 0 ;;
    --verify) cd "$OUT_DIR" && exec sha256sum -c SHA256SUMS ;;
    "")       ;;
    *)        die "opzione sconosciuta: $1" ;;
esac

# ---- controlli preliminari ---------------------------------------------------
command -v dpkg-deb >/dev/null 2>&1 || die "serve dpkg-deb (pacchetto dpkg)."
command -v python3  >/dev/null 2>&1 || die "serve python3."
for f in ruscacleaner.py ruscacleaner.svg "${DOCS[@]}"; do
    [ -f "$SRC_DIR/$f" ] || die "manca $f"
done
for l in "${LANGS[@]}"; do
    [ -f "$SRC_DIR/lang/$l.json" ] || die "manca lang/$l.json"
done
grep -qx "APP_VERSION = \"$PKG_VERSION\"" "$SRC_DIR/ruscacleaner.py" \
    || die "APP_VERSION in ruscacleaner.py è diversa da $PKG_VERSION"
python3 -c 'import ast, sys; ast.parse(open(sys.argv[1], encoding="utf-8").read())' \
    "$SRC_DIR/ruscacleaner.py" || die "ruscacleaner.py non è Python valido"

# Ogni traduzione deve avere esattamente le chiavi e i segnaposto di en.json.
# Lo stesso passaggio produce i Comment[xx] del lanciatore dalle traduzioni,
# così il testo ha una sola fonte.
DESKTOP_COMMENTS="$(python3 - "$SRC_DIR/lang" "${LANGS[@]}" <<'PY'
import json, re, sys
folder, codes = sys.argv[1], sys.argv[2:]
def load(code):
    with open(f"{folder}/{code}.json", encoding="utf-8") as handle:
        return json.load(handle)
marks = lambda text: sorted(re.findall(r"\{[a-z_]+\}", text))
ref, problems, lines = load("en"), [], []
for code in codes:
    data = load(code)
    problems += [f"{code}: manca {k}" for k in ref if k not in data]
    problems += [f"{code}: chiave sconosciuta {k}" for k in data if k not in ref]
    problems += [f"{code}: segnaposto diversi in {k}" for k in ref
                 if k in data and marks(data[k]) != marks(ref[k])]
    key = "Comment" if code == "en" else f"Comment[{code}]"
    lines.append(f"{key}={data.get('app_subtitle', ref['app_subtitle'])}")
if problems:
    sys.exit("\n".join(problems))
print("\n".join(lines))
PY
)" || die "traduzioni incomplete (vedi sopra)"

# ---- allestimento --------------------------------------------------------------
say "Allestimento di $PKG_NAME $PKG_VERSION"
rm -rf "$STAGE"
rm -f "$OUT_DIR"/*.deb "$OUT_DIR/SHA256SUMS"
mkdir -p "$STAGE/DEBIAN" "$STAGE/usr/bin" "$STAGE/$LIB_DIR/lang" "$STAGE/$DOC_DIR" \
         "$STAGE/usr/share/applications" "$STAGE/usr/share/icons/hicolor/scalable/apps"

# Il programma cerca lang/ e l'icona accanto a sé (Path(__file__).resolve()):
# /usr/bin/ruscacleaner è un collegamento che resolve() riporta qui.
install -m 0755 "$SRC_DIR/ruscacleaner.py"  "$STAGE/$LIB_DIR/ruscacleaner.py"
install -m 0644 "$SRC_DIR/ruscacleaner.svg" "$STAGE/$LIB_DIR/ruscacleaner.svg"
for l in "${LANGS[@]}"; do
    install -m 0644 "$SRC_DIR/lang/$l.json" "$STAGE/$LIB_DIR/lang/$l.json"
done
ln -s "../lib/$PKG_NAME/ruscacleaner.py" "$STAGE/usr/bin/$PKG_NAME"
install -m 0644 "$SRC_DIR/ruscacleaner.svg" \
        "$STAGE/usr/share/icons/hicolor/scalable/apps/$APP_ID.svg"

cat > "$STAGE/usr/share/applications/$APP_ID.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=RuscaCleaner
GenericName=Privacy cleaner
$DESKTOP_COMMENTS
Exec=$PKG_NAME
TryExec=$PKG_NAME
Icon=$APP_ID
Terminal=false
Categories=GTK;GNOME;Utility;
Keywords=privacy;clean;trash;history;thumbnails;clipboard;
DESKTOP

# ---- documentazione --------------------------------------------------------------
cat > "$STAGE/$DOC_DIR/copyright" <<'COPYRIGHT'
Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
Upstream-Name: RuscaCleaner
Upstream-Contact: Nunzio Curcuruto <info@ruscalinux.org>
Source: https://ruscalinux.org/

Files: *
Copyright: 2026 Nunzio Curcuruto
License: GPL-3+
Comment: Developed with the support of AI tools: design, specifications,
 review and editorial responsibility remain with the author.

License: GPL-3+
 This program is free software: you can redistribute it and/or modify it
 under the terms of the GNU General Public License as published by the Free
 Software Foundation, either version 3 of the License, or (at your option)
 any later version.
 .
 This program is distributed in the hope that it will be useful, but WITHOUT
 ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
 more details.
 .
 On Debian systems, the complete text of the GNU General Public License
 version 3 can be found in "/usr/share/common-licenses/GPL-3".
COPYRIGHT

cat > "$OUT_DIR/changelog" <<CHANGELOG
${PKG_NAME} (${PKG_VERSION}) unstable; urgency=medium

  * Interfaccia in 15 lingue (en, zh_CN, es, hi, ar, pt_BR, ru, ja, de, fr,
    it, ko, id, tr, pl), con varianti xx_YY e rispetto di LANGUAGE.
  * Nuove voci: cronologia degli appunti, indice di ricerca, registri di
    sessione, cronologie degli editor; miniature e file recenti delle app
    Flatpak; più cronologie di shell e strumenti.
  * File .deb con suffisso ${DEB_SUFFIX}, costruito in build-deb/.
  * Manuali MANUAL_en.md e MANUAL_it.md.

 -- ${MAINTAINER}  ${DATE_RFC}
CHANGELOG
gzip -9n -c "$OUT_DIR/changelog" > "$STAGE/$DOC_DIR/changelog.gz"
rm -f "$OUT_DIR/changelog"
for doc in "${DOCS[@]}"; do
    install -m 0644 "$SRC_DIR/$doc" "$STAGE/$DOC_DIR/"
done

# ---- metadati DEBIAN ---------------------------------------------------------------
# Cache delle icone e database dei lanciatori si aggiornano con i trigger di
# dpkg dichiarati da hicolor-icon-theme e desktop-file-utils: niente postinst.
INSTALLED_KB="$(du -sk "$STAGE/usr" | cut -f1)"
cat > "$STAGE/DEBIAN/control" <<CONTROL
Package: ${PKG_NAME}
Version: ${PKG_VERSION}
Architecture: ${ARCH}
Maintainer: ${MAINTAINER}
Installed-Size: ${INSTALLED_KB}
Depends: python3 (>= 3.10), python3-gi, gir1.2-gtk-4.0, gir1.2-adw-1 (>= 1.5)
Recommends: hicolor-icon-theme
Section: utils
Priority: optional
Homepage: ${HOMEPAGE}
Description: privacy cleaner for the GNOME desktop
 RuscaCleaner removes activity traces from the user's home folder:
 thumbnails, recent files, clipboard history, the search index, file
 manager metadata, session logs, shell, tool and editor histories, and the
 trash, including the trash on mounted drives.
 .
 It works only inside the home folder and validated trash folders, refuses
 to run as root, never follows symbolic links and always asks for
 confirmation listing the real paths. It is not a secure wipe: data may
 remain recoverable from the device, snapshots and backups.
CONTROL

(cd "$STAGE" && find usr -type f -exec md5sum {} + | sort -k2) > "$STAGE/DEBIAN/md5sums"

find "$STAGE" -type d -exec chmod 0755 {} +
chmod 0644 "$STAGE/DEBIAN/control" "$STAGE/DEBIAN/md5sums"
find "$STAGE" -exec touch -h -d "@$SOURCE_DATE_EPOCH" {} +

# ---- costruzione -----------------------------------------------------------------
say "Costruzione di $DEB_FILE"
dpkg-deb --root-owner-group --build "$STAGE" "$OUT_DIR/$DEB_FILE" >/dev/null
rm -rf "$STAGE"

say "Generazione di SHA256SUMS"
(cd "$OUT_DIR" && sha256sum -- *.deb > SHA256SUMS)
cat "$OUT_DIR/SHA256SUMS"

say "Fatto"
echo "Pacchetto : build-deb/$DEB_FILE"
echo "Checksum  : build-deb/SHA256SUMS"
echo "Ispezione : dpkg-deb -I build-deb/$DEB_FILE && dpkg-deb -c build-deb/$DEB_FILE"
echo "Installaz.: sudo apt install ./build-deb/$DEB_FILE"
if command -v lintian >/dev/null 2>&1; then
    say "Lintian (facoltativo)"
    lintian "$OUT_DIR/$DEB_FILE" || true
fi
