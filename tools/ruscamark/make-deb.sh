#!/usr/bin/env bash
# make-deb.sh — pacchetto .deb di RuscaMark conforme alle specifiche
# dei RuscaLinux OS Tools (SPECIFICHE-RUSCALINUX-OS-TOOLS.md).
#
# Uso: bash make-deb.sh
#   (dalla cartella con ruscamark.py, lang/, docs/, ruscamark.svg)
#   i18n integrato in ruscamark.py: il vecchio i18n.py non serve più.
#
# Conformità alle specifiche:
#   * script dedicato make-deb.sh;
#   * deb, staging e SHA256SUMS nella sotto-cartella build-deb/,
#     separata dai sorgenti;
#   * nome del pacchetto Debian: ruscamark; il suffisso -ruscalinux
#     compare solo nel nome del file .deb (ruscamark-ruscalinux_*.deb);
#   * versione identica a RuscaLinux (1.99.2);
#   * 15 lingue ufficiali (varianti zh_CN e pt_BR), fallback en.json;
#   * Python >= 3.10, GTK 4, dipendenze minime;
#   * Recommends: hunspell-en-gb (ortografia en_GB, controllo presente);
#   * GPL-3.0, nota IA, elaborazione solo locale (no telemetria).
#
# Ortografia  : libspelling (gir1.2-spelling-1) o GSpell 2; il binding
#               python3-enchant NON è usato né raccomandato.
# Traduzione  : ASSENTE per scelta (nessun motore LLM, nessun servizio).
#
# NOTA 1: DEBIAN/control è costruito con righe `echo` (non heredoc) per
#         evitare errori di delimitazione della descrizione.
# NOTA 2: ARCH=all perché il pacchetto contiene solo Python e risorse;
#         gli esempi delle specifiche mostrano amd64, ma Debian Policy
#         impone "all" per i pacchetti indipendenti dall'architettura.
set -euo pipefail

APP="ruscamark"                    # nome applicazione: binario, icone, dati
PKG="ruscamark"                    # nome del pacchetto Debian (apt, dpkg)
SUFFIX="ruscalinux"                # suffisso obbligatorio, solo nel nome del file
VER="1.99.2"                       # identica alla versione di RuscaLinux
ARCH="all"
MAINT="Nunzio Curcuruto <info@ruscalinux.org>"
HOMEPAGE="https://ruscalinux.org"

APP_ID="org.ruscalinux.ruscamark"   # = application_id in ruscamark.py
DESKTOP_ID="${APP_ID}.desktop"       # GNOME associa la finestra a questo file

OUT="build-deb"
# Struttura di lavoro temporanea dentro build-deb/: viene cancellata alla
# fine (anche in caso di errore), così restano solo il .deb e SHA256SUMS.
STAGE="${OUT}/.staging"
ROOT="${STAGE}/${PKG}_${VER}_${ARCH}"
DEB_NAME="${PKG}-${SUFFIX}_${VER}_${ARCH}.deb"

# ---- controlli preliminari ---------------------------------------------------
[ -f ruscamark.py ]  || { echo "ERRORE: ruscamark.py non trovato."; exit 1; }
[ -f ruscamark.svg ] || { echo "ERRORE: ruscamark.svg non trovato."; exit 1; }
# Privacy e sicurezza sono documentate nei manuali docs/Manual_{it,en}.md.

# Le 15 lingue ufficiali sono in lang/*.json. Inglese e italiano sono anche
# incorporati in ruscamark.py, quindi il programma funziona comunque.
LANGS="en zh_CN es hi ar pt_BR ru ja de fr it ko id tr pl"
HAVE_I18N=1
for l in $LANGS; do
    if [ ! -f "lang/${l}.json" ]; then
        echo "AVVISO: lang/${l}.json mancante (quella lingua userà l'inglese)."
        HAVE_I18N=0
    elif command -v python3 >/dev/null 2>&1 && \
         ! python3 -c "import json,sys; json.load(open(sys.argv[1], encoding='utf-8'))" "lang/${l}.json"; then
        echo "ERRORE: lang/${l}.json non è un JSON valido."; exit 1
    fi
done
[ -f docs/Manual_it.md ] && [ -f docs/Manual_en.md ] || \
    echo "AVVISO: docs/Manual_it.md o docs/Manual_en.md mancanti: manuali non inclusi."

# Il motore Markdown è integrato: python3-markdown non è più necessario.
RECOMMENDS="gir1.2-spelling-1, gir1.2-gtksource-5, hunspell-it, hunspell-en-gb"
SUGGESTS="xdg-utils, hunspell-en-us"

rm -rf "$OUT"
trap 'rm -rf "$STAGE"' EXIT
mkdir -p "${ROOT}/DEBIAN" \
    "${ROOT}/usr/bin" \
    "${ROOT}/usr/share/${APP}" \
    "${ROOT}/usr/share/applications" \
    "${ROOT}/usr/share/icons/hicolor/scalable/apps" \
    "${ROOT}/usr/share/metainfo" \
    "${ROOT}/usr/share/doc/${PKG}"

# ---- programma + lanciatore --------------------------------------------------
install -m 755 ruscamark.py "${ROOT}/usr/share/${APP}/ruscamark.py"
cat > "${ROOT}/usr/bin/${APP}" <<'LAUNCHER'
#!/bin/sh
exec python3 /usr/share/ruscamark/ruscamark.py "$@"
LAUNCHER
chmod 755 "${ROOT}/usr/bin/${APP}"

# ---- internazionalizzazione --------------------------------------------------
install -d "${ROOT}/usr/share/${APP}/lang"
for f in lang/*.json; do
    [ -e "$f" ] || continue
    install -m 644 "$f" "${ROOT}/usr/share/${APP}/lang/"
done

# ---- icona -------------------------------------------------------------------
install -m 644 ruscamark.svg "${ROOT}/usr/share/icons/hicolor/scalable/apps/${APP}.svg"

# ---- voce .desktop -----------------------------------------------------------
# Il nome del file coincide con l'identificativo dell'applicazione: su
# Wayland GTK 4 annuncia l'app_id org.ruscalinux.ruscamark e GNOME cerca
# org.ruscalinux.ruscamark.desktop per mostrare l'icona nel pannello.
cat > "${ROOT}/usr/share/applications/${DESKTOP_ID}" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=RuscaMark
GenericName=Markdown Editor
Comment=Editor Markdown con resa live, pagina centrata e ortografia live
Comment[it]=Editor Markdown con resa live, pagina centrata e ortografia live
Comment[en]=Markdown editor with live rendering, centred page and live spelling
Exec=ruscamark %F
Icon=ruscamark
Terminal=false
Categories=Utility;TextEditor;
MimeType=text/markdown;text/x-markdown;
StartupWMClass=org.ruscalinux.ruscamark
StartupNotify=true
Keywords=markdown;editor;scrittura;
DESKTOP

# ---- metainfo AppStream ------------------------------------------------------
cat > "${ROOT}/usr/share/metainfo/${APP_ID}.metainfo.xml" <<'METAINFO'
<?xml version="1.0" encoding="UTF-8"?>
<component type="desktop-application">
  <id>org.ruscalinux.ruscamark</id>
  <metadata_license>CC0-1.0</metadata_license>
  <project_license>GPL-3.0-or-later</project_license>
  <name>RuscaMark</name>
  <summary>Editor Markdown con resa live, pagina centrata e ortografia live</summary>
  <description>
    <p>RuscaMark è un editor Markdown orientato alla scrittura: resa live della
    formattazione durante la digitazione, pagina centrata, temi dal rosa al
    prugna, controllo ortografico live con suggerimenti nel menu contestuale
    (libspelling / GSpell 2), tabelle, immagini, liste di attività e note a
    piè di pagina, obiettivo parole, barra Trova/Sostituisci, export HTML e
    PDF. Tutta l'elaborazione avviene in locale: nessun dato viene inviato
    su internet.</p>
    <p>Interfaccia tradotta nelle 15 lingue ufficiali di RuscaLinux,
    commutabili dalle Preferenze.</p>
    <p>Sviluppato con il supporto di strumenti AI (Qwen): progettazione,
    specifiche, revisione e responsabilità editoriale sono dell'autore.</p>
  </description>
  <launchable type="desktop-id">org.ruscalinux.ruscamark.desktop</launchable>
  <url type="homepage">https://ruscalinux.org</url>
  <provides>
    <binary>ruscamark</binary>
  </provides>
  <content_rating type="oars-1.1"/>
  <releases>
    <release version="1.99.2" date="2026-09-27"/>
  </releases>
</component>
METAINFO

# ---- documentazione ----------------------------------------------------------
# I manuali includono anche le note di privacy e sicurezza (sezione 15).
for doc in docs/Manual_it.md docs/Manual_en.md; do
    if [ -f "$doc" ]; then
        install -m 644 "$doc" "${ROOT}/usr/share/doc/${PKG}/"
    fi
done

cat > "${ROOT}/usr/share/doc/${PKG}/copyright" <<'COPYRIGHT'
Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
Upstream-Name: RuscaMark
Upstream-Contact: Nunzio Curcuruto <info@ruscalinux.org>
Source: https://ruscalinux.org

Files: *
Copyright: 2026 Nunzio Curcuruto
License: GPL-3.0+
 Sviluppato con il supporto di strumenti AI (Qwen): progettazione,
 specifiche, revisione e responsabilità editoriale sono dell'autore.
 .
 Su sistemi Debian il testo completo della GPL-3 è in:
 /usr/share/common-licenses/GPL-3
COPYRIGHT

# ---- changelog Debian (DEP-1, gzip -9n) --------------------------------------
cat > "${ROOT}/usr/share/doc/${PKG}/changelog.Debian" <<CHANGELOG
${PKG} (${VER}) unstable; urgency=medium

  * Export PDF diretto (Ctrl+Maiusc+P): solo il contenuto del documento,
    senza intestazioni, piè di pagina o riferimenti al programma. Anche
    l'export HTML non aggiunge più piè di pagina né meta "generator".
  * Icona corretta nel pannello GNOME: file .desktop rinominato in
    org.ruscalinux.ruscamark.desktop, uguale all'identificativo
    dell'applicazione (app_id su Wayland, WM_CLASS su X11).
  * make-deb.sh non lascia più la cartella di lavoro dentro build-deb/.
  * Il pacchetto si chiama di nuovo "ruscamark"; il suffisso -ruscalinux
    resta solo nel nome del file .deb. Sostituisce il pacchetto
    "ruscamark-ruscalinux" delle build precedenti.
  * Motore Markdown integrato (nessuna dipendenza): tabelle con
    allineamento, immagini mostrate in anteprima, liste di attività, note
    a piè di pagina, link a riferimento, evidenziato, titoli setext.
  * Comandi di scrittura: grassetto (Ctrl+B), corsivo (Ctrl+I), link
    (Ctrl+K), immagine (Ctrl+Maiusc+I), tabella/allinea (Ctrl+Maiusc+T),
    titoli (Ctrl+1…6, Ctrl+0).
  * Export HTML: percorsi immagine corretti, opzione immagini incorporate,
    stile di stampa per PDF dal browser.
  * Pagina centrata anche dopo ridimensionamento e massimizzazione.
  * i18n integrato in ruscamark.py; 15 lingue tradotte; arabo RTL.
  * Versione allineata a RuscaLinux ${VER}: resa live della formattazione,
    pagina centrata, ortografia live (libspelling/GSpell 2) con elisioni
    it/fr, obiettivo parole, Trova/Sostituisci ed export HTML.
  * Corretta la persistenza del controllo ortografico: la scelta
    attivo/disattivo ora viene salvata in config.json e rispettata al
    riavvio.
  * Corretto "Trova e sostituisci": la ricerca usa Gtk.TextIter
    (GTK 4 non espone più forward_search su Gtk.TextBuffer); la
    sostituzione singola ora raggiunge l'occorrenza anche senza
    selezione preventiva.
  * Conformità alle specifiche RuscaLinux OS Tools: script make-deb.sh,
    cartella build-deb/, suffisso -ruscalinux nel nome del file, SHA256SUMS, 15 lingue
    ufficiali (varianti zh_CN e pt_BR), fallback inglese, Python >= 3.10,
    Recommends hunspell-en-gb.

-- ${MAINT}  Sun, 27 Sep 2026 12:00:00 +0200
CHANGELOG
gzip -9n "${ROOT}/usr/share/doc/${PKG}/changelog.Debian"

# ---- permessi ----------------------------------------------------------------
find "${ROOT}/usr" -type d -exec chmod 755 {} +
find "${ROOT}/usr" -type f -exec chmod 644 {} +
chmod 755 "${ROOT}/usr/bin/${APP}" "${ROOT}/usr/share/${APP}/ruscamark.py"

# ---- dimensione installata ---------------------------------------------------
SIZE_KB=$(du -sk "${ROOT}/usr" | cut -f1)

# ---- DEBIAN/control (costruito a righe, non heredoc) -------------------------
{
    echo "Package: ${PKG}"
    echo "Version: ${VER}"
    echo "Architecture: ${ARCH}"
    echo "Maintainer: ${MAINT}"
    echo "Depends: python3 (>= 3.10), python3-gi, python3-gi-cairo, gir1.2-gtk-4.0, librsvg2-common, fonts-dejavu-core"
    echo "Recommends: ${RECOMMENDS}"
    echo "Suggests: ${SUGGESTS}"
    # Le build precedenti si chiamavano "ruscamark-ruscalinux" e installavano
    # gli stessi file: Replaces+Conflicts rende pulito l'aggiornamento.
    # (Un pacchetto non può dichiarare conflitto con il proprio nome.)
    echo "Replaces: ${PKG}-${SUFFIX}"
    echo "Conflicts: ${PKG}-${SUFFIX}"
    echo "Section: editors"
    echo "Priority: optional"
    echo "Homepage: ${HOMEPAGE}"
    echo "Installed-Size: ${SIZE_KB}"
    echo "Description: Editor Markdown con resa live per la scrittura"
    echo " RuscaMark applica la formattazione Markdown durante la digitazione e"
    echo " centra la pagina come un foglio di scrittura. Tabelle, immagini, liste"
    echo " di attività e note a piè di pagina. Temi dal rosa al prugna,"
    echo " controllo ortografico live con suggerimenti nel menu contestuale"
    echo " (libspelling / GSpell 2), interfaccia nelle 15 lingue ufficiali di"
    echo " RuscaLinux, obiettivo parole, Trova/Sostituisci ed export HTML."
    echo " Nessuna traduzione automatica: il programma non integra motori LLM"
    echo " né servizi esterni; tutta l'elaborazione avviene in locale."
    echo " ."
    echo " Sviluppato con supporto AI (Qwen): progettazione, specifiche, revisione"
    echo " e responsabilità editoriale sono dell'autore."
} > "${ROOT}/DEBIAN/control"

# ---- validazioni opzionali (non bloccanti) -----------------------------------
command -v desktop-file-validate >/dev/null 2>&1 && \
    desktop-file-validate "${ROOT}/usr/share/applications/${DESKTOP_ID}" || true
command -v appstreamcli >/dev/null 2>&1 && \
    appstreamcli validate "${ROOT}/usr/share/metainfo/${APP_ID}.metainfo.xml" || true

# ---- costruzione e impronta --------------------------------------------------
dpkg-deb --build --root-owner-group -Zxz -z9 "${ROOT}" "${OUT}/${DEB_NAME}"
( cd "${OUT}" && sha256sum *.deb > SHA256SUMS )
rm -rf "$STAGE"

# ---- riepilogo ---------------------------------------------------------------
echo
echo "Pacchetto creato : ${OUT}/${DEB_NAME}"
echo "Dimensione       : $(du -h "${OUT}/${DEB_NAME}" | cut -f1)"
echo "i18n             : $([ "$HAVE_I18N" -eq 1 ] && echo '15 lingue ufficiali (fallback en)' || echo 'lingue parziali (fallback en/it incorporati)')"
echo "Traduzione       : assente (scelta progettuale)"
echo
cat "${OUT}/SHA256SUMS"
echo
echo "Installa :  sudo apt install ./${OUT}/${DEB_NAME}"
echo "Verifica :  sha256sum -c ${OUT}/SHA256SUMS"
echo "Audit    :  lintian ${OUT}/${DEB_NAME}   (se installato)"
echo "Rimuovi  :  sudo apt remove ${PKG}"