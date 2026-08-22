#!/bin/bash
#
# Costruisce i pacchetti .deb che finiscono nella ISO.
#
# Vengono messi in local/extra_debs/, che NON sta in git: sono il risultato
# di branding/ e tools/, non sorgenti. build.sh li ricostruisce da solo se
# la cartella non c'e'. Lancia questo script a mano dopo aver cambiato
# qualcosa in branding/ o in tools/.
set -e

cd "$(dirname "$0")"
. ./release.conf

QUI="$(pwd)"
FUORI="$QUI/local/extra_debs"

rm -rf "$FUORI"
mkdir -p "$FUORI"


# --- Icone, sfondi, caratteri ----------------------------------------------
#
# Ognuno di questi script sta accanto ai file che impacchetta e scrive il
# .deb nella cartella corrente: per questo prima ci si sposta in $FUORI.

cd "$FUORI"

echo "==> Icone"
bash "$QUI/branding/icons/make-icons-deb.sh" \
     "$QUI/branding/icons/Adwaita-Prugna.tar.xz" "$BRANDING_VERSION" > /dev/null

echo "==> Sfondi"
bash "$QUI/branding/backgrounds/make-backgrounds-deb.sh" \
     "$QUI/branding/backgrounds/ruscalinux-backgrounds.tar.xz" "$BRANDING_VERSION" > /dev/null

echo "==> Caratteri"
bash "$QUI/branding/fonts/make-fonts-deb.sh" \
     "$QUI/branding/fonts/DM_Sans,Syne.zip" "$BRANDING_VERSION" > /dev/null


# --- Utility di RuscaLinux -------------------------------------------------
#
# Ogni cartella dentro tools/ e' un'applicazione. Per aggiungerne una basta
# creare tools/<nome>/ con dentro un file VERSION e uno script
# make-<nome>-deb.sh: questo ciclo la trova da solo, senza modifiche qui.

for CARTELLA in "$QUI"/tools/*/; do
    NOME=$(basename "$CARTELLA")
    echo "==> $NOME"
    bash "$CARTELLA/make-$NOME-deb.sh" "$(cat "$CARTELLA/VERSION")" > /dev/null
done


# --- RuscaWriter -----------------------------------------------------------
#
# Non si costruisce qui: si scarica l'ultima release pubblicata, cosi' la ISO
# contiene sempre quella che gli utenti possono scaricare anche loro.
#
# L'indirizzo non e' scritto da nessuna parte, viene ricavato: la pagina
# releases/latest rimanda al tag piu' recente, e il nome del pacchetto segue
# il tag. Cosi' non c'e' nessun numero di versione di RuscaWriter da tenere
# aggiornato in questo repository.

echo "==> RuscaWriter"

# releases/latest non e' una pagina: rimanda al tag piu' recente. Con
# --max-redirect=0 wget non segue il rimando e ci lascia leggere l'indirizzo
# di destinazione, da cui si ricava il tag.
INDIRIZZO=$(wget -q -S --max-redirect=0 -O /dev/null \
            "https://github.com/$RUSCAWRITER_REPO/releases/latest" 2>&1 \
            | grep -i '^ *location:' | head -n 1 | sed 's|.*/||; s|\r$||')

TAG="$INDIRIZZO"

if [ -n "$TAG" ]; then
    BASE="https://github.com/$RUSCAWRITER_REPO/releases/download/$TAG"
    FILE="ruscawriter_${TAG#v}-1.ruscalinux1_all.deb"

    if wget -q -O "$FUORI/$FILE" "$BASE/$FILE"; then

        # Confronta con il checksum pubblicato insieme alla release.
        if wget -q -O /tmp/rw-sums "$BASE/SHA256SUMS"; then
            ATTESO=$(grep "$FILE" /tmp/rw-sums | cut -d ' ' -f 1)
            OTTENUTO=$(sha256sum "$FUORI/$FILE" | cut -d ' ' -f 1)
            if [ -n "$ATTESO" ] && [ "$ATTESO" != "$OTTENUTO" ]; then
                echo "ERRORE: il file scaricato non corrisponde al checksum pubblicato."
                rm -f "$FUORI/$FILE"
                exit 1
            fi
        fi

        # Ne tiene una copia, cosi' una build senza rete funziona lo stesso.
        cp "$FUORI/$FILE" "$QUI/vendor/ruscawriter_latest_all.deb"
        echo "    $TAG scaricato"
    fi
fi

# Se il download non e' riuscito, usa la copia salvata l'ultima volta.
if ! ls "$FUORI"/ruscawriter_*.deb > /dev/null 2>&1; then
    if [ -f "$QUI/vendor/ruscawriter_latest_all.deb" ]; then
        # Il nome vero del pacchetto si legge dal pacchetto stesso, cosi' nella
        # ISO finisce con lo stesso nome che avrebbe avuto scaricandolo.
        COPIA="$QUI/vendor/ruscawriter_latest_all.deb"
        VERS=$(dpkg-deb -f "$COPIA" Version)
        cp "$COPIA" "$FUORI/ruscawriter_${VERS}_all.deb"
        echo "    senza rete: uso la copia in vendor/ ($VERS)"
    else
        echo
        echo "ERRORE: RuscaWriter non scaricato e non c'e' una copia in vendor/."
        echo "        Controlla la connessione, oppure scarica a mano l'ultima"
        echo "        release da https://github.com/$RUSCAWRITER_REPO/releases"
        echo "        e mettila in vendor/ruscawriter_latest_all.deb"
        exit 1
    fi
fi


echo
echo "Pacchetti pronti in local/extra_debs/:"
ls -1sh "$FUORI"/*.deb | sed 's|/.*/|  |'
