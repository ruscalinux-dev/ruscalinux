#!/bin/bash
# make-fonts-deb.sh
# Genera un pacchetto .deb per ogni famiglia di font trovata nello zip.
# Supporta zip con più famiglie (es. DM Sans + Space Grotesk + Syne).
# Scaricabili da https://fonts.google.com
# Personalizzato per RuscaLinux
#
# Uso:
#   chmod +x make-fonts-deb.sh
#   ./make-fonts-deb.sh Fonts.zip
#   ./make-fonts-deb.sh Fonts.zip 2.001   # versione globale custom (applicata a tutti)
#   ./make-fonts-deb.sh Fonts.zip "" static-only   # solo font statici (no variabili)

set -euo pipefail

# ── Identità RuscaLinux ───────────────────────────────────────────────────────
RL_VENDOR="RuscaLinux"
RL_MAINTAINER="RuscaLinux Project <fonts@ruscalinux.org>"
RL_HOMEPAGE="https://www.ruscalinux.org"
RL_VERSION_SUFFIX="~ruscalinux1"
# ─────────────────────────────────────────────────────────────────────────────

# ── Colori ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}  ▸${RESET} $*"; }
ok()      { echo -e "${GREEN}  ✓${RESET} $*"; }
warn()    { echo -e "${YELLOW}  ⚠${RESET} $*"; }
die()     { echo -e "${RED}  ✗ ERRORE:${RESET} $*" >&2; exit 1; }
section() { echo -e "\n${BOLD}$*${RESET}"; }

# ── Argomenti ─────────────────────────────────────────────────────────────────
ZIP="${1:-}"
GLOBAL_VERSION="${2:-}"        # se vuoto, viene rilevato per ciascuna famiglia
STATIC_ONLY="${3:-}"           # "static-only" → esclude i font variabili VariableFont

[[ -z "$ZIP" ]] && die "Specifica lo zip come primo argomento.\n  Uso: $0 Fonts.zip [versione] [static-only]"
[[ -f "$ZIP" ]] || die "File non trovato: $ZIP"
ZIP="$(cd "$(dirname "$ZIP")" && pwd)/$(basename "$ZIP")"

# ── Dipendenze ────────────────────────────────────────────────────────────────
section "[$RL_VENDOR] fonts — multi-family builder"
info "Controllo dipendenze..."
for cmd in dpkg-deb unzip; do
    command -v "$cmd" &>/dev/null || die "Comando non trovato: $cmd  (installa dpkg / unzip)"
done
ok "Dipendenze OK"

HAS_FONTTOOLS=false
if command -v python3 &>/dev/null && python3 -c "import fontTools" &>/dev/null 2>&1; then
    HAS_FONTTOOLS=true
fi

# ── Funzioni di supporto ──────────────────────────────────────────────────────

# Converte il nome cartella "DM_Sans" / "Space_Grotesk" / "Syne" → "dm-sans" / "space-grotesk" / "syne"
# Usa il nome della directory (underscore come separatore) per preservare le sigle (DM, non D-M)
family_to_slug() {
    local name="$1"
    echo "$name" | tr '_' '-' | tr '[:upper:]' '[:lower:]'
}

# Ricava la versione dal primo TTF tramite fontTools; fallback a "1.0"
detect_version() {
    local ttf="$1"
    if $HAS_FONTTOOLS; then
        python3 - "$ttf" 2>/dev/null <<'EOF' || echo "1.0"
import sys
from fontTools.ttLib import TTFont
tt = TTFont(sys.argv[1])
for r in tt['name'].names:
    if r.nameID == 5:
        v = r.toUnicode().replace('Version ', '').strip().split(';')[0]
        print(v)
        break
EOF
    else
        echo "1.0"
    fi
}

# Costruisce e verifica un singolo pacchetto .deb
build_deb() {
    local FAMILY_DIR="$1"      # es. /tmp/xyz/extracted/DM_Sans
    local FAMILY_NAME="$2"     # es. DMSans  (nome base dei file TTF, usato nei log)
    local DISPLAY_NAME="$3"    # es. "DM Sans"  (leggibile)
    local VERSION="$4"
    local WORKDIR="$5"
    local FOLDER_NAME="$6"     # es. DM_Sans  (nome cartella, base per lo slug)

    section "  Famiglia: ${BOLD}${DISPLAY_NAME}${RESET}"

    # ── Raccolta TTF ──────────────────────────────────────────────────────────
    local -a TTFS=()

    if [[ "$STATIC_ONLY" == "static-only" ]]; then
        # Solo font dalla sottocartella static/
        mapfile -t TTFS < <(find "$FAMILY_DIR/static" -name "*.ttf" 2>/dev/null | sort)
        [[ ${#TTFS[@]} -eq 0 ]] && {
            warn "Nessun TTF statico trovato in $FAMILY_DIR/static — famiglia saltata."
            return 0
        }
    else
        # Font variabili nella root + statici nella sottocartella
        mapfile -t TTFS < <(find "$FAMILY_DIR" -name "*.ttf" | sort)
        [[ ${#TTFS[@]} -eq 0 ]] && {
            warn "Nessun TTF trovato in $FAMILY_DIR — famiglia saltata."
            return 0
        }
    fi

    info "Font trovati (${#TTFS[@]}):"
    for f in "${TTFS[@]}"; do printf "      %s\n" "$(basename "$f")"; done

    # ── Versione ──────────────────────────────────────────────────────────────
    local FULL_VERSION="${VERSION}${RL_VERSION_SUFFIX}"
    local SLUG
    SLUG=$(family_to_slug "$FOLDER_NAME")
    local PKG="ruscalinux-fonts-${SLUG}"
    local ARCH="all"
    local PKGNAME="${PKG}_${FULL_VERSION}_${ARCH}"
    local PKGDIR="${WORKDIR}/${PKGNAME}"

    # ── Struttura .deb ────────────────────────────────────────────────────────
    info "Costruzione struttura pacchetto..."

    local FONTDIR="${PKGDIR}/usr/share/fonts/truetype/${SLUG}"
    local DOCDIR="${PKGDIR}/usr/share/doc/${PKG}"
    local DEBDIR="${PKGDIR}/DEBIAN"

    mkdir -p "$FONTDIR" "$DOCDIR" "$DEBDIR"

    # Copia i font preservando la struttura static/ se presenti entrambi i tipi
    for f in "${TTFS[@]}"; do
        # I variabili stanno nella root della famiglia, gli statici in static/
        if [[ "$f" == */static/* ]]; then
            mkdir -p "${FONTDIR}/static"
            cp "$f" "${FONTDIR}/static/"
        else
            cp "$f" "${FONTDIR}/"
        fi
    done
    ok "${#TTFS[@]} file TTF copiati"

    # Licenza OFL (cerca in tutta la cartella della famiglia)
    local OFL
    OFL=$(find "$FAMILY_DIR" -maxdepth 2 \( -iname "OFL*.txt" -o -iname "LICENSE*.txt" \) -print -quit 2>/dev/null)
    [[ -n "$OFL" ]] && cp "$OFL" "$DOCDIR/OFL.txt"

    # copyright
    cat > "$DOCDIR/copyright" << EOF
Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
Upstream-Name: ${DISPLAY_NAME}
Source: https://fonts.google.com/specimen/$(echo "$DISPLAY_NAME" | tr ' ' '+')

Files: *
License: OFL-1.1
 This Font Software is licensed under the SIL Open Font License, Version 1.1.
 Full text: https://openfontlicense.org

Packaging:
 Packaged for $RL_VENDOR — $RL_HOMEPAGE
EOF

    # changelog
    local CHLOG="${WORKDIR}/changelog-${SLUG}"
    cat > "$CHLOG" << EOF
${PKG} (${FULL_VERSION}) unstable; urgency=low

  * Pacchetto generato da make-fonts-deb.sh.
  * Pacchettizzato per $RL_VENDOR.

 -- $RL_MAINTAINER  $(date -R)
EOF
    gzip -9 -n "$CHLOG"
    cp "${CHLOG}.gz" "$DOCDIR/changelog.gz"

    # Dimensione installata in KB
    local INSTALLED_KB
    INSTALLED_KB=$(du -sk "${PKGDIR}/usr" | awk '{print $1}')

    # Elenco pesi inclusi (nomi file senza estensione, breve)
    local WEIGHTS
    WEIGHTS=$(for f in "${TTFS[@]}"; do basename "$f" .ttf; done | \
              grep -v 'VariableFont' | sed 's/^[^-]*-//' | sort -u | tr '\n' ' ')

    # control
    cat > "$DEBDIR/control" << EOF
Package: ${PKG}
Version: ${FULL_VERSION}
Architecture: ${ARCH}
Vendor: ${RL_VENDOR}
Maintainer: ${RL_MAINTAINER}
Installed-Size: ${INSTALLED_KB}
Depends: fontconfig
Section: fonts
Priority: optional
Homepage: ${RL_HOMEPAGE}
Description: ${DISPLAY_NAME} font family (for ${RL_VENDOR})
 ${DISPLAY_NAME} è una famiglia di caratteri sans-serif
 distribuita tramite Google Fonts con licenza OFL-1.1.
 .
 Varianti incluse: ${WEIGHTS:-N/D}
 .
 Pacchettizzato per ${RL_VENDOR} — ${RL_HOMEPAGE}
EOF

    # postinst
    cat > "$DEBDIR/postinst" << EOF
#!/bin/sh
set -e
if which fc-cache > /dev/null 2>&1; then
    echo "[${RL_VENDOR}] Aggiornamento cache font..."
    fc-cache -f "/usr/share/fonts/truetype/${SLUG}"
fi
EOF
    chmod 755 "$DEBDIR/postinst"

    # postrm
    cat > "$DEBDIR/postrm" << 'EOF'
#!/bin/sh
set -e
if which fc-cache > /dev/null 2>&1; then
    fc-cache -f
fi
EOF
    chmod 755 "$DEBDIR/postrm"

    ok "Struttura pacchetto pronta"

    # ── Build ──────────────────────────────────────────────────────────────────
    local OUTFILE
    OUTFILE="$(pwd)/${PKGNAME}.deb"
    info "Build: ${PKGNAME}.deb"
    dpkg-deb --build --root-owner-group "$PKGDIR" "$OUTFILE"

    # ── Riepilogo ──────────────────────────────────────────────────────────────
    echo ""
    echo -e "  ${BOLD}Riepilogo:${RESET}"
    dpkg-deb --info "$OUTFILE" \
        | grep -E "Package|Version|Architecture|Installed-Size|Depends|Vendor" \
        | sed 's/^/    /'
    echo ""
    echo -e "  ${BOLD}Contenuto font:${RESET}"
    dpkg-deb --contents "$OUTFILE" | grep "\.ttf" | awk '{print "      " $NF}'
    echo ""

    local SIZE
    SIZE=$(du -sh "$OUTFILE" | cut -f1)
    ok "Pacchetto generato: ${BOLD}$(basename "$OUTFILE")${RESET}  (${SIZE})"
    echo -e "  Per installare: ${CYAN}sudo dpkg -i $(basename "$OUTFILE")${RESET}"

    # Registra il .deb generato nella variabile globale per il riepilogo finale
    BUILT_PACKAGES+=("$(basename "$OUTFILE")")
}

# ── Estrazione zip ────────────────────────────────────────────────────────────
WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

info "Estrazione: $ZIP"
unzip -q "$ZIP" -d "$WORKDIR/extracted"

# ── Rilevamento famiglie ──────────────────────────────────────────────────────
# Una "famiglia" è una sotto-directory di primo livello che contiene almeno un .ttf
section "Rilevamento famiglie di font..."

declare -a FAMILY_DIRS=()
while IFS= read -r -d '' dir; do
    # find -print -quit esce da solo: senza questo, head/grep chiudono la
    # pipe, find muore di SIGPIPE e "set -o pipefail" fa fallire lo script
    # in modo intermittente (dipende da quanti file ci sono).
    if [[ -n "$(find "$dir" -maxdepth 2 -name "*.ttf" -print -quit)" ]]; then
        FAMILY_DIRS+=("$dir")
    fi
done < <(find "$WORKDIR/extracted" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)

[[ ${#FAMILY_DIRS[@]} -eq 0 ]] && die "Nessuna cartella di font trovata nello zip."

info "Famiglie trovate: ${#FAMILY_DIRS[@]}"
for d in "${FAMILY_DIRS[@]}"; do echo "    $(basename "$d")"; done

# ── Loop su ogni famiglia ─────────────────────────────────────────────────────
declare -a BUILT_PACKAGES=()

for FAMILY_DIR in "${FAMILY_DIRS[@]}"; do
    # Nome cartella (es. "DM_Sans", "Space_Grotesk", "Syne")
    FOLDER_NAME=$(basename "$FAMILY_DIR")

    # Nome del font ricavato dal primo TTF trovato (es. "DMSans", "SpaceGrotesk", "Syne")
    FIRST_TTF=$(find "$FAMILY_DIR" -name "*.ttf" -print -quit)
    FONT_BASENAME=$(basename "$FIRST_TTF" .ttf)
    # Prefisso = tutto prima del primo trattino (es. "DMSans")
    FONT_PREFIX="${FONT_BASENAME%%-*}"

    # Nome leggibile: sostituisce _ con spazio nel nome cartella (es. "DM Sans")
    DISPLAY_NAME="${FOLDER_NAME//_/ }"

    # ── Versione per questa famiglia ──────────────────────────────────────────
    if [[ -n "$GLOBAL_VERSION" ]]; then
        VERSION="$GLOBAL_VERSION"
    else
        VERSION=$(detect_version "$FIRST_TTF")
        if [[ "$VERSION" == "1.0" ]] && ! $HAS_FONTTOOLS; then
            warn "fontTools non disponibile, versione impostata a 1.0 per $DISPLAY_NAME"
        else
            ok "Versione rilevata per ${DISPLAY_NAME}: $VERSION"
        fi
    fi

    build_deb "$FAMILY_DIR" "$FONT_PREFIX" "$DISPLAY_NAME" "$VERSION" "$WORKDIR" "$FOLDER_NAME"
done

# ── Riepilogo finale ──────────────────────────────────────────────────────────
section "══ Riepilogo finale ══"
echo -e " Vendor:            ${CYAN}${RL_VENDOR}${RESET}"
echo -e " Pacchetti generati: ${BOLD}${#BUILT_PACKAGES[@]}${RESET}"
for pkg in "${BUILT_PACKAGES[@]}"; do
    echo -e "   ${GREEN}✓${RESET}  $pkg"
done
echo ""
