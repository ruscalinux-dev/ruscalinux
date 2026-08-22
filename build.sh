#!/bin/bash
#
# Costruisce la ISO di RuscaLinux.
#
#   ./build.sh            costruisce tutto
#   ./build.sh --config   si ferma prima della build lunga (per controllare)
#   ./build.sh --clean    cancella il lavoro precedente e basta
#
# "set -e" ferma lo script appena un comando fallisce, invece di proseguire
# e produrre una ISO incompleta.
set -e

# Va sempre nella cartella dello script, anche se lo lanci da altrove.
cd "$(dirname "$0")"

# Carica VERSION, SUITE, ARCH e le altre impostazioni.
. ./release.conf


# --- Opzioni ---------------------------------------------------------------

SOLO_CONFIG=no

if [ "$1" = "--clean" ]; then
    sudo rm -rf .work .gen
    echo "Cancellati .work e .gen"
    exit 0
fi

if [ "$1" = "--config" ]; then
    SOLO_CONFIG=si
fi

echo "RuscaLinux $VERSION — $SUITE/$ARCH"


# --- 1. Controlli ----------------------------------------------------------

if ! command -v lb > /dev/null; then
    echo "ERRORE: manca live-build.  Installalo con:  sudo apt install live-build"
    exit 1
fi

# Serve per scaricare RuscaWriter dal suo repository.
if ! command -v wget > /dev/null; then
    echo "ERRORE: manca wget.  Installalo con:  sudo apt install wget"
    exit 1
fi

if [ "$(id -u)" = "0" ]; then
    echo "ERRORE: non lanciare questo script come root. Usa il tuo utente:"
    echo "        lo script chiama sudo da solo dove serve."
    exit 1
fi


# --- 2. Pacchetti .deb -----------------------------------------------------
#
# I .deb non stanno in git: sono prodotti da make-debs.sh a partire da
# branding/ e tools/. Se la cartella non c'e', li costruisce adesso.

echo
echo "==> Pacchetti"

if [ ! -d local/extra_debs ]; then
    ./make-debs.sh
fi

# Controlla che ci siano davvero. Una ISO senza RuscaWriter o senza una
# utility si costruisce lo stesso, e te ne accorgeresti solo dopo l'avvio.
for atteso in ruscawriter $(ls tools/); do
    trovato=$(ls local/extra_debs/${atteso}_*.deb 2> /dev/null | head -n 1)
    if [ -z "$trovato" ]; then
        echo "ERRORE: manca il pacchetto $atteso."
        echo "        Rilancia ./make-debs.sh e leggi cosa dice."
        exit 1
    fi
    echo "    $atteso $(dpkg-deb -f "$trovato" Version)"
done


# --- 3. Scrive la versione negli script ------------------------------------
#
# Gli script in steps/ contengono @VERSION@ al posto del numero. Qui vengono
# copiati in .gen/ con il numero vero. Cosi' la versione e' scritta in un
# posto solo: release.conf.

echo
echo "==> Versione $VERSION"

rm -rf .gen
mkdir .gen

for file in steps/*.sh; do
    sed -e "s|@VERSION@|$VERSION|g" \
        -e "s|@SUITE@|$SUITE|g" \
        -e "s|@ARCH@|$ARCH|g" \
        -e "s|@MIRROR@|$MIRROR|g" \
        "$file" > ".gen/$(basename "$file")"
done


# --- 4. Prepara la configurazione di live-build ----------------------------

echo
echo "==> Configurazione"

sudo rm -rf .work

sh .gen/10-config.sh
sh .gen/20-packages.sh
sh .gen/30-custom.sh

if [ "$SOLO_CONFIG" = "si" ]; then
    echo
    echo "Fermato prima della build (--config)."
    exit 0
fi


# --- 5. Costruisce la ISO --------------------------------------------------

echo
echo "==> Costruzione della ISO (ci vuole parecchio)"

cd .work
sudo lb build
cd ..

# live-build aggiunge da solo "-amd64.hybrid" al nome che gli abbiamo dato.
ISO="ruscalinux-$VERSION-$ARCH.hybrid.iso"

if [ ! -f ".work/$ISO" ]; then
    echo "ERRORE: la ISO non e' stata prodotta. Guarda i messaggi qui sopra."
    exit 1
fi

cd .work
sha256sum "$ISO" > SHA256SUMS
cd ..

PESO=$(du -h ".work/$ISO" | cut -f 1)
SHA=$(cut -d ' ' -f 1 .work/SHA256SUMS)


# --- 6. Documenti del rilascio ---------------------------------------------
#
# RELEASE-NOTES.md e i due file in dist/ contengono @VERSION@, @SHA256@ e
# simili al posto dei valori veri. Qui vengono riempiti con quelli di questa
# ISO. Serve a non ricopiare a mano un checksum di 64 caratteri: se lo sbagli,
# la verifica fallisce a chiunque scarichi e non se ne accorge nessuno.
#
# Il numero di pacchetti lo conta live-build, nel file .packages che scrive
# accanto alla ISO: e' l'unico modo di averlo giusto.

PACCHETTI=$(wc -l < ".work/ruscalinux-$VERSION-$ARCH.packages" 2> /dev/null || echo "?")
OGGI=$(date +%Y-%m-%d)

riempi() {                        # riempi  MODELLO  DESTINAZIONE
    sed -e "s|@VERSION@|$VERSION|g" \
        -e "s|@SUITE@|$SUITE|g" \
        -e "s|@ARCH@|$ARCH|g" \
        -e "s|@KERNEL@|$KERNEL|g" \
        -e "s|@DESKTOP@|$DESKTOP|g" \
        -e "s|@ISO@|$ISO|g" \
        -e "s|@SHA256@|$SHA|g" \
        -e "s|@SIZE@|$PESO|g" \
        -e "s|@PACCHETTI@|$PACCHETTI|g" \
        -e "s|@DATE@|$OGGI|g" \
        "$1" > "$2"
}

riempi RELEASE-NOTES.md "RELEASE-NOTES-$VERSION.md"
riempi dist/README.md   .work/README.md
riempi dist/INSTALL.md  .work/INSTALL.md


echo
echo "Fatto: RuscaLinux $VERSION"
echo "  file       .work/$ISO"
echo "  peso       $PESO"
echo "  sha256     $SHA"
echo "  pacchetti  $PACCHETTI"
echo
echo "Da caricare su SourceForge, tutti in .work/ :"
echo "  $ISO"
echo "  SHA256SUMS"
echo "  ruscalinux-$VERSION-$ARCH.packages"
echo "  README.md   INSTALL.md"
echo
echo "Per la release GitHub:  RELEASE-NOTES-$VERSION.md"
echo
echo "Adesso:  ./test.sh    provala in QEMU"
echo "         poi pubblica a mano — la lista dei passi e' in COME-FUNZIONA.md"
