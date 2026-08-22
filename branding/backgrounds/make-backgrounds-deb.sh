#!/bin/bash

# Script per convertire un archivio di sfondi in pacchetto .deb per GNOME
# Personalizzato per RuscaLinux
# Uso: ./make-backgrounds-deb.sh <archivio-sfondi> [versione]

set -e

# ── Identità RuscaLinux ───────────────────────────────────────────────────────
RL_VENDOR="RuscaLinux"
RL_MAINTAINER="RuscaLinux Project <packager@ruscalinux.org>"
RL_HOMEPAGE="https://www.ruscalinux.org"
RL_VERSION_SUFFIX="~ruscalinux1"
# ─────────────────────────────────────────────────────────────────────────────

if [ $# -eq 0 ]; then
    echo "Uso: $0 <archivio-sfondi> [versione]"
    echo "Esempio: $0 ruscalinux-backgrounds.tar.xz 1.0"
    echo ""
    echo "Formati supportati: .tar.gz, .tar.xz, .tar.bz2, .zip"
    exit 1
fi

ARCHIVE="$1"
VERSION="${2:-1.0}${RL_VERSION_SUFFIX}"

if [ ! -f "$ARCHIVE" ]; then
    echo "Errore: File $ARCHIVE non trovato"
    exit 1
fi

# Estrai il nome del pacchetto dall'archivio, aggiunge prefisso ruscalinux-
ARCHIVE_BASENAME=$(basename "$ARCHIVE")
RAW_NAME="${ARCHIVE_BASENAME%%.*}"
RAW_NAME=$(echo "$RAW_NAME" | tr '[:upper:]' '[:lower:]' | tr '_' '-')

# Aggiunge prefisso solo se non già presente
if [[ "$RAW_NAME" == ruscalinux-* ]]; then
    PACKAGE_NAME="$RAW_NAME"
else
    PACKAGE_NAME="ruscalinux-${RAW_NAME}"
fi

ARCH="all"

echo "==> Vendor: $RL_VENDOR"
echo "==> Conversione sfondi: $PACKAGE_NAME"
echo "==> Versione: $VERSION"

# Salva la directory corrente
ORIGINAL_DIR="$(pwd)"

# Rendi assoluto il percorso dell'archivio: senza questo, un percorso
# assoluto passato come argomento verrebbe concatenato a ORIGINAL_DIR.
ARCHIVE="$(cd "$(dirname "$ARCHIVE")" && pwd)/$(basename "$ARCHIVE")"

# Crea directory temporanea
TEMP_DIR=$(mktemp -d)
EXTRACT_DIR="$TEMP_DIR/extract"
BUILD_DIR="$TEMP_DIR/${PACKAGE_NAME}_${VERSION}_${ARCH}"

mkdir -p "$EXTRACT_DIR"
cd "$EXTRACT_DIR"

# Estrai l'archivio in base al formato
echo "==> Estrazione archivio..."
case "$ARCHIVE" in
    *.tar.xz)
        tar -xf "$ARCHIVE"
        ;;
    *.tar.gz)
        tar -xzf "$ARCHIVE"
        ;;
    *.tar.bz2)
        tar -xjf "$ARCHIVE"
        ;;
    *.zip)
        unzip -q "$ARCHIVE"
        ;;
    *)
        echo "Errore: Formato archivio non supportato"
        echo "Formati supportati: .tar.xz, .tar.gz, .tar.bz2, .zip"
        rm -rf "$TEMP_DIR"
        exit 1
        ;;
esac

echo "==> Contenuto estratto:"
ls -la "$EXTRACT_DIR"

# Trova i file immagine
echo "==> Ricerca file immagine..."
IMAGE_FILES=$(find "$EXTRACT_DIR" -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.webp" \) | wc -l)

if [ "$IMAGE_FILES" -eq 0 ]; then
    echo "Errore: Nessun file immagine trovato nell'archivio"
    echo "Formati supportati: .png, .jpg, .jpeg, .webp"
    rm -rf "$TEMP_DIR"
    exit 1
fi

echo "==> Trovati $IMAGE_FILES file immagine"

# Crea struttura pacchetto Debian
echo "==> Creazione struttura pacchetto..."
mkdir -p "$BUILD_DIR/DEBIAN"
mkdir -p "$BUILD_DIR/usr/share/backgrounds/$PACKAGE_NAME"
mkdir -p "$BUILD_DIR/usr/share/gnome-background-properties"

# Copia tutti i file immagine
echo "==> Copia sfondi..."
find "$EXTRACT_DIR" -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.webp" \) \
    -exec cp {} "$BUILD_DIR/usr/share/backgrounds/$PACKAGE_NAME/" \;

# Conta i file effettivamente copiati
COPIED_FILES=$(find "$BUILD_DIR/usr/share/backgrounds/$PACKAGE_NAME" -type f | wc -l)
echo "==> Copiati $COPIED_FILES file"

# Crea file control
echo "==> Creazione file control..."
cat > "$BUILD_DIR/DEBIAN/control" << EOF
Package: $PACKAGE_NAME
Version: $VERSION
Section: x11
Priority: optional
Architecture: $ARCH
Vendor: $RL_VENDOR
Maintainer: $RL_MAINTAINER
Homepage: $RL_HOMEPAGE
Description: $(echo "$PACKAGE_NAME" | sed 's/-/ /g') wallpapers collection
 A collection of wallpapers for the RuscaLinux desktop environment.
 This package includes $COPIED_FILES high-quality background images
 that can be used with GNOME.
 .
 The wallpapers are installed in /usr/share/backgrounds/$PACKAGE_NAME/
 and are automatically available in GNOME Settings.
 .
 Built for $RL_VENDOR — $RL_HOMEPAGE
EOF

# Crea file XML per GNOME
echo "==> Creazione configurazione GNOME..."
cat > "$BUILD_DIR/usr/share/gnome-background-properties/$PACKAGE_NAME.xml" << 'XML_START'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE wallpapers SYSTEM "gnome-wp-list.dtd">
<wallpapers>
XML_START

# Aggiungi ogni sfondo al file XML
for wallpaper in "$BUILD_DIR/usr/share/backgrounds/$PACKAGE_NAME"/*; do
    if [ -f "$wallpaper" ]; then
        BASENAME=$(basename "$wallpaper")
        FILENAME="${BASENAME%.*}"
        # Il nome mostrato nel pannello Sfondi di GNOME. Dal nome del file
        # vanno tolti il seed e la risoluzione, altrimenti l'utente legge
        # "Ruscalinux Wallpaper Dark 4526880 3840x2160" invece di
        # "RuscaLinux — Dark".
        VARIANT=$(echo "$FILENAME" \
            | sed -e 's/^ruscalinux-wallpaper-//' \
                  -e 's/-[0-9]\+x[0-9]\+//g' \
                  -e 's/-[0-9]\{3,\}//g' \
                  -e 's/[-_]/ /g' \
                  -e 's/^ *//; s/ *$//')
        case "$VARIANT" in
            light) VARIANT="Light" ;;
            mid)   VARIANT="Mid"   ;;
            dark)  VARIANT="Dark"  ;;
            *)     VARIANT=$(echo "$VARIANT" | sed 's/\b\(.\)/\u\1/g') ;;
        esac
        if [ -n "$VARIANT" ]; then
            DISPLAY_NAME="RuscaLinux — $VARIANT"
        else
            DISPLAY_NAME="RuscaLinux"
        fi

        cat >> "$BUILD_DIR/usr/share/gnome-background-properties/$PACKAGE_NAME.xml" << EOF
  <wallpaper deleted="false">
    <name>$DISPLAY_NAME</name>
    <filename>/usr/share/backgrounds/$PACKAGE_NAME/$BASENAME</filename>
    <options>zoom</options>
    <shade_type>solid</shade_type>
    <pcolor>#000000</pcolor>
    <scolor>#000000</scolor>
  </wallpaper>
EOF
    fi
done

cat >> "$BUILD_DIR/usr/share/gnome-background-properties/$PACKAGE_NAME.xml" << 'XML_END'
</wallpapers>
XML_END

# Crea script postinst
cat > "$BUILD_DIR/DEBIAN/postinst" << EOF
#!/bin/bash
set -e

echo ""
echo "[$RL_VENDOR] Sfondi installati con successo!"
echo "Puoi trovarli in: Impostazioni → Aspetto → Sfondo"
echo ""

exit 0
EOF
chmod +x "$BUILD_DIR/DEBIAN/postinst"

# Crea script postrm
cat > "$BUILD_DIR/DEBIAN/postrm" << EOF
#!/bin/bash
set -e

if [ "\$1" = "purge" ]; then
    rmdir /usr/share/backgrounds/$PACKAGE_NAME 2>/dev/null || true
fi

exit 0
EOF
chmod +x "$BUILD_DIR/DEBIAN/postrm"

# Correggi permessi
echo "==> Correzione permessi..."
find "$BUILD_DIR/usr/share/backgrounds" -type f -exec chmod 644 {} \;
find "$BUILD_DIR/usr/share/backgrounds" -type d -exec chmod 755 {} \;
chmod 644 "$BUILD_DIR/usr/share/gnome-background-properties/$PACKAGE_NAME.xml"

# Calcola dimensione installata (in KB)
INSTALLED_SIZE=$(du -sk "$BUILD_DIR/usr" | cut -f1)
echo "Installed-Size: $INSTALLED_SIZE" >> "$BUILD_DIR/DEBIAN/control"

# Costruisci il pacchetto
echo "==> Costruzione pacchetto .deb..."
cd "$TEMP_DIR"
dpkg-deb --build --root-owner-group "$BUILD_DIR"

# Sposta il pacchetto nella directory originale
DEB_FILE="${PACKAGE_NAME}_${VERSION}_${ARCH}.deb"
mv "${BUILD_DIR}.deb" "$ORIGINAL_DIR/$DEB_FILE"

# Pulizia
echo "==> Pulizia files temporanei..."
rm -rf "$TEMP_DIR"

cd "$ORIGINAL_DIR"

echo ""
echo "✅ Pacchetto creato con successo: $DEB_FILE"
echo ""
echo "Contenuto del pacchetto:"
echo "  - $COPIED_FILES sfondi in /usr/share/backgrounds/$PACKAGE_NAME/"
echo "  - Configurazione GNOME per visualizzazione automatica"
echo "  - Dimensione: $(du -h "$DEB_FILE" | cut -f1)"
echo "  - Vendor: $RL_VENDOR"
echo ""
echo "Per installare:"
echo "  sudo dpkg -i $DEB_FILE"
echo ""
echo "Per disinstallare:"
echo "  sudo apt remove $PACKAGE_NAME"
echo ""
echo "Dopo l'installazione, gli sfondi saranno disponibili in:"
echo "  Impostazioni → Aspetto → Sfondo"
