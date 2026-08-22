#!/bin/bash

# Script per convertire un archivio di icone in pacchetto .deb per GNOME
# Personalizzato per RuscaLinux
# Uso: ./icons-deb.sh <archivio-icone> [versione]

set -e

# ── Identità RuscaLinux ───────────────────────────────────────────────────────
RL_VENDOR="RuscaLinux"
RL_MAINTAINER="RuscaLinux Project <packager@ruscalinux.org>"
RL_HOMEPAGE="https://www.ruscalinux.org"
RL_VERSION_SUFFIX="~ruscalinux1"
# ─────────────────────────────────────────────────────────────────────────────

if [ $# -eq 0 ]; then
    echo "Uso: $0 <archivio-icone> [versione]"
    echo "Esempio: $0 Adwaita-Red.tar.xz 1.0"
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

# Estrai il nome del tema dall'archivio
ARCHIVE_BASENAME=$(basename "$ARCHIVE")
THEME_NAME="${ARCHIVE_BASENAME%%.*}"
RAW_PACKAGE=$(echo "$THEME_NAME" | tr '[:upper:]' '[:lower:]' | tr '_' '-')

# Aggiunge prefisso ruscalinux- solo se non già presente
if [[ "$RAW_PACKAGE" == ruscalinux-* ]]; then
    PACKAGE_NAME="$RAW_PACKAGE"
else
    PACKAGE_NAME="ruscalinux-${RAW_PACKAGE}"
fi

ARCH="all"

echo "==> Vendor: $RL_VENDOR"
echo "==> Conversione tema icone: $THEME_NAME"
echo "==> Nome pacchetto: $PACKAGE_NAME"
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

# Trova la directory principale del tema
THEME_DIR=""
if [ -f "index.theme" ] || [ -f "index.desktop" ]; then
    THEME_DIR="$EXTRACT_DIR"
elif [ -d "$THEME_NAME" ]; then
    THEME_DIR="$EXTRACT_DIR/$THEME_NAME"
else
    for dir in "$EXTRACT_DIR"/*/ ; do
        if [ -f "$dir/index.theme" ] || [ -f "$dir/index.desktop" ]; then
            THEME_DIR="$dir"
            break
        fi
    done
fi

if [ -z "$THEME_DIR" ] || [ ! -d "$THEME_DIR" ]; then
    echo "Errore: Non riesco a trovare la directory del tema con index.theme"
    echo "Contenuto estratto:"
    ls -la "$EXTRACT_DIR"
    rm -rf "$TEMP_DIR"
    exit 1
fi

echo "==> Tema trovato in: $THEME_DIR"

if [ ! -f "$THEME_DIR/index.theme" ]; then
    echo "Attenzione: File index.theme non trovato, il tema potrebbe non funzionare correttamente"
fi

# Crea struttura pacchetto Debian
echo "==> Creazione struttura pacchetto..."
mkdir -p "$BUILD_DIR/DEBIAN"
mkdir -p "$BUILD_DIR/usr/share/icons"

# Copia il tema
echo "==> Copia tema icone..."
cp -r "$THEME_DIR" "$BUILD_DIR/usr/share/icons/$THEME_NAME"

# Leggi informazioni dal file index.theme se esiste
THEME_COMMENT="Icon theme for GNOME"
if [ -f "$BUILD_DIR/usr/share/icons/$THEME_NAME/index.theme" ]; then
    THEME_COMMENT=$(grep -m1 "^Comment=" "$BUILD_DIR/usr/share/icons/$THEME_NAME/index.theme" | cut -d'=' -f2- || echo "Icon theme for GNOME")
fi

# Crea file control
echo "==> Creazione file control..."
cat > "$BUILD_DIR/DEBIAN/control" << EOF
Package: $PACKAGE_NAME
Version: $VERSION
Section: x11
Priority: optional
Architecture: $ARCH
Vendor: $RL_VENDOR
Depends: gtk-update-icon-cache
Maintainer: $RL_MAINTAINER
Homepage: $RL_HOMEPAGE
Description: $THEME_NAME icon theme (for $RL_VENDOR)
 $THEME_COMMENT
 .
 This package provides the $THEME_NAME icon theme for GTK/GNOME desktop
 environments. After installation, you can select it in your system
 settings under Appearance or Tweaks.
 .
 Built for $RL_VENDOR — $RL_HOMEPAGE
EOF

# Crea script postinst
cat > "$BUILD_DIR/DEBIAN/postinst" << EOF
#!/bin/bash
set -e

if command -v gtk-update-icon-cache > /dev/null 2>&1; then
    for theme_dir in /usr/share/icons/*/; do
        if [ -f "\${theme_dir}index.theme" ]; then
            gtk-update-icon-cache -q -t -f "\$theme_dir" 2>/dev/null || true
        fi
    done
fi

echo ""
echo "[$RL_VENDOR] Tema icone installato con successo!"
echo ""
echo "Per attivare il tema:"
echo "  - GNOME Tweaks: Aspetto → Icone"
echo "  - Oppure da terminale:"
echo "    gsettings set org.gnome.desktop.interface icon-theme '$THEME_NAME'"
echo ""

exit 0
EOF
chmod +x "$BUILD_DIR/DEBIAN/postinst"

# Crea script postrm
cat > "$BUILD_DIR/DEBIAN/postrm" << 'EOF'
#!/bin/bash
set -e

if [ "$1" = "remove" ] || [ "$1" = "purge" ]; then
    if command -v gtk-update-icon-cache > /dev/null 2>&1; then
        for theme_dir in /usr/share/icons/*/; do
            if [ -f "${theme_dir}index.theme" ]; then
                gtk-update-icon-cache -q -t -f "$theme_dir" 2>/dev/null || true
            fi
        done
    fi
fi

exit 0
EOF
chmod +x "$BUILD_DIR/DEBIAN/postrm"

# Correggi permessi
echo "==> Correzione permessi..."
find "$BUILD_DIR/usr/share/icons" -type f -exec chmod 644 {} \;
find "$BUILD_DIR/usr/share/icons" -type d -exec chmod 755 {} \;

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
echo "Informazioni pacchetto:"
echo "  Vendor: $RL_VENDOR"
echo "  Nome tema: $THEME_NAME"
echo "  Installazione in: /usr/share/icons/$THEME_NAME/"
echo "  Dimensione: $(du -h "$DEB_FILE" | cut -f1)"
echo ""
echo "Per installare:"
echo "  sudo dpkg -i $DEB_FILE"
echo "  sudo apt-get install -f  # Se ci sono dipendenze mancanti"
echo ""
echo "Per attivare il tema dopo l'installazione:"
echo "  gsettings set org.gnome.desktop.interface icon-theme '$THEME_NAME'"
echo ""
echo "Per disinstallare:"
echo "  sudo apt remove $PACKAGE_NAME"
