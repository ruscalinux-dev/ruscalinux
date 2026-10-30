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

# Servono a make-debs.sh per costruire i pacchetti di branding/ e tools/.
for comando in dpkg-deb python3; do
    if ! command -v "$comando" > /dev/null; then
        echo "ERRORE: manca $comando.  Installalo con:  sudo apt install $comando"
        exit 1
    fi
done

# Driver NVIDIA (steps/40-nvidia.sh, docs/NVIDIA.md): openssl crea la chiave
# di firma dei moduli, unsquashfs controlla che la chiave privata non sia
# finita nella ISO.
for coppia in openssl:openssl base64:coreutils unsquashfs:squashfs-tools; do
    comando=${coppia%%:*}
    pacchetto=${coppia#*:}
    if ! command -v "$comando" > /dev/null; then
        echo "ERRORE: manca $comando.  Installalo con:  sudo apt install $pacchetto"
        exit 1
    fi
done

# Chiave del repository NVIDIA, verificata con l'impronta registrata in git.
if [ ! -f local/nvidia/cuda-archive-keyring.gpg ] || [ ! -f local/nvidia/SHA256SUMS ]; then
    echo "ERRORE: manca la chiave del repository NVIDIA in local/nvidia/."
    echo "        Le istruzioni per scaricarla una volta sola sono in docs/NVIDIA.md."
    exit 1
fi
if ! ( cd local/nvidia && sha256sum --quiet -c SHA256SUMS ); then
    echo "ERRORE: la chiave in local/nvidia/ non corrisponde all'impronta registrata."
    exit 1
fi

# Chiave di firma dei moduli NVIDIA (Secure Boot). La chiave privata NON sta
# nel repository e NON finisce nella ISO: serve solo durante la build. Va
# conservata, con una copia di riserva: con una chiave nuova, chi ha gia'
# registrato la vecchia in Secure Boot dovrebbe registrarla di nuovo.
RUSCALINUX_MOK_DIR="${RUSCALINUX_MOK_DIR:-$HOME/.local/share/ruscalinux/mok}"
if [ ! -f "$RUSCALINUX_MOK_DIR/mok.key" ] || [ ! -f "$RUSCALINUX_MOK_DIR/mok.pub" ]; then
    echo "    Creo la chiave di firma dei moduli in $RUSCALINUX_MOK_DIR"
    mkdir -p "$RUSCALINUX_MOK_DIR"
    chmod 700 "$RUSCALINUX_MOK_DIR"
    openssl req -new -x509 -newkey rsa:2048 -nodes -days 36500 \
        -subj "/CN=RuscaLinux module signing key/" \
        -keyout "$RUSCALINUX_MOK_DIR/mok.key" \
        -outform DER -out "$RUSCALINUX_MOK_DIR/mok.pub" 2> /dev/null
    chmod 600 "$RUSCALINUX_MOK_DIR/mok.key"
    echo "    FAI UNA COPIA DI RISERVA di $RUSCALINUX_MOK_DIR: e' la chiave"
    echo "    che gli utenti registrano in Secure Boot."
fi
export RUSCALINUX_MOK_DIR

if [ "$(id -u)" = "0" ]; then
    echo "ERRORE: non lanciare questo script come root. Usa il tuo utente:"
    echo "        lo script chiama sudo da solo dove serve."
    exit 1
fi


# --- 2. Pacchetti .deb -----------------------------------------------------
#
# I .deb non stanno in git: sono prodotti da make-debs.sh a partire da
# branding/ e tools/. Li ricostruisce se la cartella non c'e', oppure se un
# file in branding/ o tools/ e' piu' recente dei pacchetti (le cartelle
# build-deb/ dei tool sono escluse: sono a loro volta risultati).

echo
echo "==> Pacchetti"

if [ ! -d local/extra_debs ]; then
    ./make-debs.sh
elif [ -n "$(find branding tools -name build-deb -prune -o \
             -type f -newer local/extra_debs -print -quit)" ]; then
    echo "    branding/ o tools/ sono cambiati: ricostruisco i pacchetti"
    ./make-debs.sh
fi

# Controlla che ci siano davvero. Una ISO senza una utility si costruisce
# lo stesso, e te ne accorgeresti solo dopo l'avvio.
#
# Si guarda il nome del pacchetto scritto DENTRO il .deb, non il nome del
# file: i tool producono <nome>-ruscalinux_<versione>_all.deb.
for cartella in tools/*/; do
    atteso=$(basename "$cartella")
    trovato=""
    for deb in local/extra_debs/*.deb; do
        [ -f "$deb" ] || continue
        if [ "$(dpkg-deb -f "$deb" Package)" = "$atteso" ]; then
            trovato="$deb"
            break
        fi
    done
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
        -e "s|@NVIDIA_PIN@|$NVIDIA_PIN|g" \
        -e "s|@NVIDIA_REPO@|$NVIDIA_REPO|g" \
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
sh .gen/40-nvidia.sh

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

# La chiave privata di firma dei moduli NVIDIA non deve essere nella ISO.
# L'hook la cancella; qui si controlla.
if sudo unsquashfs -l .work/binary/live/filesystem.squashfs \
        | grep -E 'mok\.key|nvidia-driver\.hook' > /dev/null; then
    echo "ERRORE: nella ISO c'e' la chiave privata di firma. ISO eliminata."
    rm -f ".work/$ISO"
    exit 1
fi
echo "    Controllo chiave privata: assente dalla ISO"

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
