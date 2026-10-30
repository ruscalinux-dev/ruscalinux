#!/bin/sh
# ===========================================================================
# DRIVER NVIDIA — eseguito da build.sh dopo i tre passi standard.
#
# La ISO contiene il driver dal repository ufficiale NVIDIA (moduli aperti,
# ramo fissato da NVIDIA_PIN in release.conf), ma SI AVVIA E SI INSTALLA
# CON I DRIVER LIBERI. Il driver NVIDIA si sceglie nel menu di avvio:
#
#   Live system (amd64)                         driver liberi (predefinita)
#   Live system (amd64) with NVIDIA driver      driver NVIDIA
#   Start installer                             installa con i driver liberi
#   Start installer with NVIDIA driver          installa con il driver NVIDIA
#
# Le voci NVIDIA aggiungono "rusca.driver=nvidia" alla riga di avvio: da
# quel parametro dipendono il pannello nvidia-settings (visibile solo col
# driver NVIDIA) e cosa resta sul sistema installato (con i driver liberi,
# driver e pannello NVIDIA vengono rimossi).
#
# Questo passo aggiunge alla configurazione gia' pronta in .work/:
#   1. contrib e i parametri di avvio dei driver liberi;
#   2. l'hook che installa e firma il driver;
#   3. l'hook che aggiunge le voci NVIDIA ai menu di avvio;
#   4. il servizio che mostra o nasconde il pannello NVIDIA;
#   5. lo script che, a fine installazione, configura il sistema su disco;
#   6. il pannello nvidia-settings nella cartella Sistema di GNOME.
#
# Spiegazioni e prove da fare: docs/NVIDIA.md
# ===========================================================================
set -e

# Parametri di avvio. Driver liberi: i moduli NVIDIA esclusi. Driver
# NVIDIA: nouveau escluso, piu' il segno letto da servizio e post-install.
LIBERI="modprobe.blacklist=nvidia,nvidia_drm,nvidia_modeset,nvidia_uvm"


# --- 1. live-build: contrib e parametri dei driver liberi ------------------
#
# lb config si puo' rilanciare: cambia solo le opzioni indicate. Le righe di
# avvio si leggono da quelle gia' scritte, cosi' non sono copiate qui.

cd .work
APPEND=$(sed -n 's/^LB_BOOTAPPEND_LIVE="\(.*\)"$/\1/p' config/binary)
FAILSAFE=$(sed -n 's/^LB_BOOTAPPEND_LIVE_FAILSAFE="\(.*\)"$/\1/p' config/binary)
if [ -z "$APPEND" ]; then
    echo "ERRORE: non trovo LB_BOOTAPPEND_LIVE in .work/config/binary" >&2
    exit 1
fi
lb config \
  --archive-areas "main contrib non-free-firmware" \
  --bootappend-live "$APPEND $LIBERI"
if [ -n "$FAILSAFE" ]; then
    lb config --bootappend-live-failsafe "$FAILSAFE $LIBERI"
else
    echo "ATTENZIONE: LB_BOOTAPPEND_LIVE_FAILSAFE vuoto: la voce fail-safe" >&2
    echo "            non esclude i moduli NVIDIA." >&2
fi
cd ..

# Grafica ibrida (GNOME: "Avvia usando la scheda grafica dedicata") e
# registrazione della chiave per Secure Boot. Restano anche con i driver
# liberi: switcheroo-control serve pure ai portatili AMD/Intel ibridi.
cat <<'EOF' > .work/config/package-lists/nvidia.list.chroot
switcheroo-control
mokutil
EOF

# --- 2. Hook: repository NVIDIA e driver -----------------------------------
#
# Il driver si installa da un hook e non da package-lists per due motivi:
#  - il pacchetto di pinning deve essere installato PRIMA del driver, e solo
#    un apt-get esplicito garantisce l'ordine;
#  - il repository e la sua chiave restano sotto il nostro controllo, senza
#    dipendere da come la versione di live-build gestisce config/archives.
#
# Le chiavi sono incluse nell'hook in base64: la chiave pubblica del
# repository (verificata da build.sh) e la coppia di chiavi di firma dei
# moduli. La chiave PRIVATA viene cancellata alla fine dell'hook e non entra
# nella ISO.

HOOK=.work/config/hooks/normal/0500-nvidia-driver.hook.chroot
mkdir -p .work/config/hooks/normal/

{
    echo '#!/bin/sh'
    echo '# Scritto da steps/40-nvidia.sh — non modificare qui.'
    echo 'set -e'
    echo
    echo 'scrivi_repo_key() {'
    echo "    base64 -d <<'B64'"
    base64 local/nvidia/cuda-archive-keyring.gpg
    echo 'B64'
    echo '}'
    echo
    echo 'scrivi_mok_key() {'
    echo "    base64 -d <<'B64'"
    base64 "$RUSCALINUX_MOK_DIR/mok.key"
    echo 'B64'
    echo '}'
    echo
    echo 'scrivi_mok_pub() {'
    echo "    base64 -d <<'B64'"
    base64 "$RUSCALINUX_MOK_DIR/mok.pub"
    echo 'B64'
    echo '}'
} > "$HOOK"

cat <<'EOF' >> "$HOOK"

PIN="@NVIDIA_PIN@"
REPO="@NVIDIA_REPO@"
KEYRING=/usr/share/keyrings/ruscalinux-nvidia-archive.gpg
LISTA=/etc/apt/sources.list.d/ruscalinux-nvidia.list
export DEBIAN_FRONTEND=noninteractive

# --- Repository NVIDIA ---
scrivi_repo_key > "$KEYRING"
chmod 644 "$KEYRING"
echo "deb [signed-by=$KEYRING] $REPO /" > "$LISTA"

# --- Chiavi di firma dei moduli (DKMS le usa se le trova qui) ---
mkdir -p /var/lib/dkms
( umask 077; scrivi_mok_key > /var/lib/dkms/mok.key )
scrivi_mok_pub > /var/lib/dkms/mok.pub

apt-get update

# DKMS cerca il programma sign-file in un percorso che dipende dall'ID di
# os-release (qui "ruscalinux", non "debian") e dalla versione del kernel: su
# trixie non lo trova e salta la firma senza avvisare. Glielo indichiamo.
# Il file si toglie alla fine dell'hook.
SIGN_FILE=$(find /usr/lib -path '*/linux-kbuild-*/scripts/sign-file' 2> /dev/null | sort -V | tail -n 1)
if [ -n "$SIGN_FILE" ]; then
    mkdir -p /etc/dkms/framework.conf.d
    cat > /etc/dkms/framework.conf.d/ruscalinux-firma.conf <<CONF
mok_signing_key="/var/lib/dkms/mok.key"
mok_certificate="/var/lib/dkms/mok.pub"
sign_file="$SIGN_FILE"
CONF
    echo "Firma dei moduli: sign-file in $SIGN_FILE"
else
    echo "ATTENZIONE: sign-file non trovato: i moduli non saranno firmati" >&2
fi

# Prima il pinning, poi il driver: cosi' apt sceglie gia' il ramo giusto.
apt-get install --assume-yes "nvidia-driver-pinning-$PIN"
apt-get install --assume-yes nvidia-driver nvidia-kernel-open-dkms nvidia-settings

# Il pannello deve avere un file .desktop: lo script che lo mette nella
# cartella Sistema lo cerca con questo nome.
if [ -f /usr/share/applications/nvidia-settings.desktop ]; then
    echo "Pannello NVIDIA: nvidia-settings.desktop presente"
else
    echo "ATTENZIONE: manca /usr/share/applications/nvidia-settings.desktop:" >&2
    echo "            il pannello non andra' nella cartella Sistema." >&2
    ls /usr/share/applications/ | grep -i nvidia >&2 || true
fi

# --- Moduli compilati e firmati per OGNI kernel della ISO ---
# Nel chroot "uname -r" e' il kernel della macchina che costruisce, non
# quello della ISO: si ripete la compilazione per i kernel installati.

firmato() {
    [ -n "$(modinfo -F signer "$1" 2> /dev/null)" ]
}

# Se DKMS non ha firmato un modulo, lo firma l'hook. I moduli di Debian sono
# compressi con xz: si decomprimono, si firmano e si ricomprimono con le
# stesse opzioni del kernel Debian.
firma() {
    modulo=$1
    [ -n "$SIGN_FILE" ] || return 1
    case "$modulo" in
        *.ko.xz)
            nudo=${modulo%.xz}
            xz -d -c "$modulo" > "$nudo"
            "$SIGN_FILE" sha256 /var/lib/dkms/mok.key /var/lib/dkms/mok.pub "$nudo"
            xz -f --check=crc32 --lzma2=dict=1MiB "$nudo"
            ;;
        *.ko)
            "$SIGN_FILE" sha256 /var/lib/dkms/mok.key /var/lib/dkms/mok.pub "$modulo"
            ;;
        *)
            echo "ATTENZIONE: formato non previsto, non firmo $modulo" >&2
            return 1
            ;;
    esac
}

TROVATI=0
for dir in /lib/modules/*; do
    kv=$(basename "$dir")
    [ -d "/usr/src/linux-headers-$kv" ] || continue
    dkms autoinstall -k "$kv" || true

    for m in $(find "$dir/updates" -name 'nvidia*.ko*' 2> /dev/null); do
        if firmato "$m"; then
            echo "Firmato da DKMS: $(basename "$m")"
        elif firma "$m"; then
            echo "Firmato dall'hook: $(basename "$m")"
        fi
    done

    modulo=$(find "$dir/updates" -name 'nvidia.ko*' 2> /dev/null | head -n 1)
    if [ -z "$modulo" ]; then
        echo "ERRORE: il modulo nvidia non e' stato compilato per il kernel $kv" >&2
        exit 1
    fi
    if firmato "$modulo"; then
        echo "Modulo nvidia per $kv: firmato ($(modinfo -F signer "$modulo"))"
    else
        echo "ATTENZIONE: modulo nvidia per $kv NON firmato: con Secure Boot" >&2
        echo "            attivo non si carichera'." >&2
    fi
    TROVATI=$((TROVATI + 1))
done
if [ "$TROVATI" -eq 0 ]; then
    echo "ERRORE: nessun kernel con i suoi headers: manca linux-headers-amd64?" >&2
    exit 1
fi

# --- Certificato pubblico per Secure Boot; chiave privata eliminata ---
mkdir -p /usr/share/ruscalinux/nvidia
cp /var/lib/dkms/mok.pub /usr/share/ruscalinux/nvidia/ruscalinux-mok.der
chmod 644 /usr/share/ruscalinux/nvidia/ruscalinux-mok.der
command -v shred > /dev/null && shred -u /var/lib/dkms/mok.key || rm -f /var/lib/dkms/mok.key
rm -f /etc/dkms/framework.conf.d/ruscalinux-firma.conf
if [ -e /var/lib/dkms/mok.key ]; then
    echo "ERRORE: la chiave privata e' ancora in /var/lib/dkms" >&2
    exit 1
fi

# Il sistema installato e' offline (il post-install svuota sources.list):
# si toglie anche la lista NVIDIA. Chiave e pacchetto di pinning restano,
# per chi un giorno riattivasse il repository.
rm -f "$LISTA"

# --- nouveau: lo decide il menu di avvio, non un file ---
# I pacchetti NVIDIA mettono nouveau in blacklist in modo permanente. Qui il
# blacklist si neutralizza, perche' la voce "grafica di riserva" deve poter
# usare nouveau (per esempio per l'uscita HDMI di molti portatili).
# Un file in /etc/modprobe.d con lo stesso nome prevale su quello di /usr/lib.
# Prima i file di /etc (si correggono sul posto), poi quelli di /usr/lib e
# /lib, solo se in /etc non c'e' gia' un file con lo stesso nome.
for f in /etc/modprobe.d/*.conf /usr/lib/modprobe.d/*.conf /lib/modprobe.d/*.conf; do
    [ -f "$f" ] || continue
    case "$f" in
        /etc/*) ;;
        *) [ -e "/etc/modprobe.d/$(basename "$f")" ] && continue ;;
    esac
    grep -Eq '^[[:space:]]*(blacklist[[:space:]]+nouveau|options[[:space:]]+nouveau[[:space:]]+modeset=0)' "$f" || continue
    dest="/etc/modprobe.d/$(basename "$f")"
    sed -E 's/^([[:space:]]*(blacklist[[:space:]]+nouveau|options[[:space:]]+nouveau[[:space:]]+modeset=0))/# RuscaLinux, lo decide il menu di avvio: \1/' \
        "$f" > "$dest.tmp"
    mv "$dest.tmp" "$dest"
    echo "Blacklist di nouveau neutralizzato: $f"
done

# --- Opzioni del driver ---
# PreserveVideoMemoryAllocations e i servizi nvidia-suspend servono alla
# sospensione con Wayland: senza, GDM disattiva Wayland sulle GPU NVIDIA.
# /tmp su trixie e' in RAM: la memoria video si salva in /var/tmp.
cat > /etc/modprobe.d/ruscalinux-nvidia.conf <<'CONF'
# RuscaLinux — opzioni del driver NVIDIA (steps/40-nvidia.sh)
options nvidia NVreg_PreserveVideoMemoryAllocations=1 NVreg_TemporaryFilePath=/var/tmp
options nvidia_drm modeset=1 fbdev=1
CONF

# I servizi NVIDIA partono solo se il driver e' caricato: con i driver
# liberi, o su un PC senza GPU NVIDIA, la condizione non e' soddisfatta e
# systemd li salta senza bloccare la sospensione.
for unita in nvidia-suspend nvidia-resume nvidia-hibernate nvidia-suspend-then-hibernate nvidia-persistenced; do
    if [ -f "/usr/lib/systemd/system/$unita.service" ] || [ -f "/lib/systemd/system/$unita.service" ]; then
        mkdir -p "/etc/systemd/system/$unita.service.d"
        printf '[Unit]\nConditionPathExists=/proc/driver/nvidia/version\n' \
            > "/etc/systemd/system/$unita.service.d/ruscalinux.conf"
        systemctl enable "$unita.service" || true
    fi
done

# --- Pannello NVIDIA nascosto per default ---
# Il sistema parte con i driver liberi: il pannello e' nascosto da un file
# con lo stesso nome in /usr/local/share/applications, che ha la precedenza
# su /usr/share/applications. Con "rusca.driver=nvidia" il servizio
# ruscalinux-driver-mode lo toglie prima che parta il desktop.
mkdir -p /usr/local/share/applications
printf '[Desktop Entry]\nType=Application\nName=NVIDIA Settings\nHidden=true\n' \
    > /usr/local/share/applications/nvidia-settings.desktop

# Il servizio si scrive qui e non in includes.chroot_after_packages, cosi'
# esiste di sicuro quando lo si attiva. Lo script che lancia arriva dagli
# include (passo 4).
cat > /etc/systemd/system/ruscalinux-driver-mode.service <<'UNIT'
[Unit]
Description=RuscaLinux: show the NVIDIA panel only with the NVIDIA driver
Before=display-manager.service

[Service]
Type=oneshot
ExecStart=/usr/lib/ruscalinux/driver-mode

[Install]
WantedBy=multi-user.target
UNIT
systemctl enable ruscalinux-driver-mode.service

update-initramfs -u -k all
EOF
chmod +x "$HOOK"

# --- 3. Hook binario: voci NVIDIA nei menu di avvio ------------------------
#
# Gira quando live-build ha gia' scritto i menu di GRUB (UEFI) e isolinux
# (BIOS). Ogni voce NVIDIA e' la copia della voce con i driver liberi,
# inserita subito dopo, con " with NVIDIA driver" nel titolo:
#  - live: la prima voce che contiene i parametri dei driver liberi; nella
#    copia diventano "modprobe.blacklist=nouveau rusca.driver=nvidia";
#  - installer: la prima voce d'installazione di ogni menu (escluse sintesi
#    vocale, esperto, ripristino, automatica, tema scuro); nella copia si
#    aggiunge "rusca.driver=nvidia".
# Le voci predefinite restano quelle con i driver liberi. Se il formato dei
# menu cambiasse, l'hook lo segnala con un'ATTENZIONE.

cat <<'EOF' > .work/config/hooks/normal/9000-nvidia-boot-menu.hook.binary
#!/bin/sh
set -e
[ -d binary ] && cd binary

LIBERI="modprobe.blacklist=nvidia,nvidia_drm,nvidia_modeset,nvidia_uvm"
NVIDIA="modprobe.blacklist=nouveau rusca.driver=nvidia"
SEGNO="rusca.driver=nvidia"
TITOLO=" with NVIDIA driver"
ESCLUSE="speakup|priority=low|rescue/enable|auto=true|theme=dark"
LIVE=0
INSTALLER=0

# GRUB: duplica la prima voce "menuentry ... { ... }" che corrisponde.
#   modo=live       voce con i parametri dei driver liberi
#   modo=installer  voce con /install/, escluse quelle in ESCLUSE
grub_duplica() {
    awk -v modo="$1" -v liberi="$LIBERI" -v nvidia="$NVIDIA" -v segno="$SEGNO" \
        -v titolo="$TITOLO" -v escluse="$ESCLUSE" '
        function adatta(i, riga) {
            riga = blocco[i]
            if (i == 1) {
                if (match(riga, /"[^"]*"/) || match(riga, /'"'"'[^'"'"']*'"'"'/))
                    riga = substr(riga, 1, RSTART + RLENGTH - 2) titolo substr(riga, RSTART + RLENGTH - 1)
                gsub(/[ \t]--hotkey=[^ \t]*/, "", riga)
            }
            if (modo == "live") {
                gsub(liberi, nvidia, riga)
            } else if (match(riga, /^[ \t]*linux[ \t]+[^ \t]+/)) {
                riga = substr(riga, 1, RLENGTH) " " segno substr(riga, RLENGTH + 1)
            }
            return riga
        }
        function adatto(testo) {
            if (modo == "live") return index(testo, liberi) > 0
            return index(testo, "/install/") > 0 && testo !~ escluse
        }
        BEGIN { dentro = 0; fatto = 0 }
        !fatto && !dentro && /^[ \t]*menuentry[ \t]/ { dentro = 1; n = 0 }
        dentro {
            blocco[++n] = $0
            if ($0 ~ /^[ \t]*}[ \t]*$/) {
                dentro = 0; testo = ""
                for (i = 1; i <= n; i++) { print blocco[i]; testo = testo blocco[i] "\n" }
                if (adatto(testo)) {
                    fatto = 1
                    for (i = 1; i <= n; i++) print adatta(i)
                }
            }
            next
        }
        { print }
    ' "$2" > "$2.nuovo"
    if cmp -s "$2" "$2.nuovo"; then
        rm -f "$2.nuovo"
        return 1
    fi
    mv "$2.nuovo" "$2"
    echo "Menu GRUB ($1): aggiunta la voce NVIDIA in $2"
}

# isolinux (avvio BIOS): blocchi "label ..." fino alla riga vuota successiva.
isolinux_duplica() {
    awk -v modo="$1" -v liberi="$LIBERI" -v nvidia="$NVIDIA" -v segno="$SEGNO" \
        -v titolo="$TITOLO" -v escluse="$ESCLUSE" '
        function adatto(testo) {
            if (modo == "live") return index(testo, liberi) > 0
            return index(testo, "/install/") > 0 && testo !~ escluse
        }
        function chiudi(   i, testo, riga, append) {
            testo = ""; append = 0
            for (i = 1; i <= n; i++) {
                print blocco[i]; testo = testo blocco[i] "\n"
                if (blocco[i] ~ /^[ \t]*append[ \t]/) append = 1
            }
            if (!fatto && adatto(testo)) {
                fatto = 1
                print ""
                for (i = 1; i <= n; i++) {
                    riga = blocco[i]
                    if (riga ~ /^[ \t]*$/) continue
                    if (riga ~ /^[ \t]*menu[ \t]+default/) continue
                    if (riga ~ /^label[ \t]/) riga = riga "-nvidia"
                    if (riga ~ /^[ \t]*menu[ \t]+label[ \t]/) {
                        gsub(/\^/, "", riga)
                        riga = riga titolo
                    }
                    if (modo == "live") {
                        gsub(liberi, nvidia, riga)
                    } else if (append && match(riga, /^[ \t]*append/)) {
                        riga = substr(riga, 1, RLENGTH) " " segno substr(riga, RLENGTH + 1)
                    } else if (!append && match(riga, /^[ \t]*(linux|kernel)[ \t]+[^ \t]+/)) {
                        riga = substr(riga, 1, RLENGTH) " " segno substr(riga, RLENGTH + 1)
                    }
                    print riga
                }
            }
            n = 0; dentro = 0
        }
        BEGIN { dentro = 0; fatto = 0; n = 0 }
        /^label[ \t]/ { if (dentro) chiudi(); dentro = 1 }
        dentro && /^[ \t]*$/ { chiudi(); print; next }
        dentro { blocco[++n] = $0; next }
        { print }
        END { if (dentro) chiudi() }
    ' "$2" > "$2.nuovo"
    if cmp -s "$2" "$2.nuovo"; then
        rm -f "$2.nuovo"
        return 1
    fi
    mv "$2.nuovo" "$2"
    echo "Menu isolinux ($1): aggiunta la voce NVIDIA in $2"
}

# --- GRUB: voce live ---
for cfg in $(find boot/grub -name '*.cfg' 2> /dev/null | sort); do
    grep -q "$LIBERI" "$cfg" || continue
    if grep -q "$NVIDIA" "$cfg"; then LIVE=1; continue; fi
    grub_duplica live "$cfg" && LIVE=1
done

# --- GRUB: voce installer ---
# Prima il menu principale dell'installer (install_start.cfg); il menu
# avanzato (install.cfg) resta con i soli driver liberi.
if [ -f boot/grub/install_start.cfg ]; then
    FILE_INSTALLER=boot/grub/install_start.cfg
else
    FILE_INSTALLER=$(grep -l '/install/' boot/grub/*.cfg 2> /dev/null | grep -v '/install\.cfg$' || true)
fi
for cfg in $FILE_INSTALLER; do
    if grep -q "/install/.*$SEGNO" "$cfg"; then INSTALLER=1; continue; fi
    grub_duplica installer "$cfg" && INSTALLER=1
done

# --- isolinux: voce live e voce installer ---
for cfg in $(find isolinux -name '*.cfg' 2> /dev/null | sort); do
    if grep -q "$LIBERI" "$cfg" && ! grep -q "$NVIDIA" "$cfg"; then
        isolinux_duplica live "$cfg" || true
    fi
    if grep -q '/install/' "$cfg" && ! grep -q "$SEGNO" "$cfg"; then
        isolinux_duplica installer "$cfg" || true
    fi
done

[ "$LIVE" -eq 1 ] || echo "ATTENZIONE: voce live NVIDIA non aggiunta al menu GRUB." >&2
[ "$INSTALLER" -eq 1 ] || echo "ATTENZIONE: voce installer NVIDIA non aggiunta al menu GRUB." >&2
EOF
chmod +x .work/config/hooks/normal/9000-nvidia-boot-menu.hook.binary


# --- 4. Pannello NVIDIA visibile solo con il driver NVIDIA ------------------
#
# A ogni avvio, prima del desktop, il servizio ruscalinux-driver-mode
# (scritto e attivato dall'hook del passo 2) guarda la riga di avvio: con
# "rusca.driver=nvidia" toglie il file che nasconde il pannello, altrimenti
# lo rimette. Vale per la sessione live e per il sistema installato con il
# driver NVIDIA (dove la voce GRUB "free drivers" nasconde di nuovo il
# pannello).

INC=.work/config/includes.chroot_after_packages
mkdir -p "$INC/usr/lib/ruscalinux/grub.d" "$INC/etc/xdg/autostart"

cat <<'EOF' > "$INC/usr/lib/ruscalinux/driver-mode"
#!/bin/sh
# RuscaLinux — mostra o nasconde il pannello NVIDIA secondo il driver scelto
# nel menu di avvio. Scritto da steps/40-nvidia.sh.
NASCOSTO=/usr/local/share/applications/nvidia-settings.desktop
if grep -qw 'rusca.driver=nvidia' /proc/cmdline; then
    rm -f "$NASCOSTO"
else
    mkdir -p /usr/local/share/applications
    printf '[Desktop Entry]\nType=Application\nName=NVIDIA Settings\nHidden=true\n' > "$NASCOSTO"
fi
EOF
chmod +x "$INC/usr/lib/ruscalinux/driver-mode"



# --- 5. Configurazione del sistema installato ------------------------------
#
# Il debian-installer copia il sistema live sul disco, driver compreso. Il
# late_command (30-custom.sh) lascia /tmp/ruscalinux-driver-nvidia se
# l'installer e' partito dalla voce NVIDIA; ruscalinux-postinstall.sh lancia
# poi questo script per ultimo.

cat <<'EOF' > "$INC/usr/lib/ruscalinux/nvidia-postinstall"
#!/bin/sh
# RuscaLinux — driver liberi o driver NVIDIA sul sistema installato, secondo
# la voce scelta nel menu dell'installer. Scritto da steps/40-nvidia.sh;
# lanciato da ruscalinux-postinstall.sh.

if [ -e /tmp/ruscalinux-driver-nvidia ] || grep -qw 'rusca.driver=nvidia' /proc/cmdline 2> /dev/null; then
    echo ">>> Driver NVIDIA: attivo, con la voce GRUB dei driver liberi"

    # GRUB_CMDLINE_LINUX e non _DEFAULT: 99-ruscalinux.cfg imposta gia'
    # _DEFAULT ("quiet splash") e i due file non si devono sovrascrivere.
    mkdir -p /etc/default/grub.d
    cat > /etc/default/grub.d/90-ruscalinux-nvidia.cfg <<'CFG'
# RuscaLinux — driver NVIDIA attivo, nouveau escluso (nvidia-postinstall)
GRUB_CMDLINE_LINUX="$GRUB_CMDLINE_LINUX modprobe.blacklist=nouveau rusca.driver=nvidia"
CFG
    install -m 755 /usr/lib/ruscalinux/grub.d/25_ruscalinux_free_drivers \
        /etc/grub.d/25_ruscalinux_free_drivers
    update-grub || true
    exit 0
fi

echo ">>> Driver liberi: rimuovo driver e pannello NVIDIA"

for unita in nvidia-suspend nvidia-resume nvidia-hibernate \
             nvidia-suspend-then-hibernate nvidia-persistenced \
             ruscalinux-driver-mode; do
    systemctl disable "$unita.service" 2> /dev/null || true
    rm -rf "/etc/systemd/system/$unita.service.d"
done

PACCHETTI=$(dpkg-query -W -f='${db:Status-Abbrev} ${Package}\n' 2> /dev/null \
    | awk '$1 ~ /^i/ && $2 ~ /^(nvidia-|libnvidia-|libxnvctrl|xserver-xorg-video-nvidia|libcuda|libnvcuvid|libnvoptix|firmware-nvidia)/ { print $2 }')
if [ -n "$PACCHETTI" ]; then
    # Il sistema e' offline: apt rimuove soltanto, non scarica niente.
    # shellcheck disable=SC2086
    apt-get purge --assume-yes -o APT::Get::AutomaticRemove=false $PACCHETTI \
        || dpkg --purge $PACCHETTI || true
fi

rm -f /etc/modprobe.d/ruscalinux-nvidia.conf \
      /etc/systemd/system/ruscalinux-driver-mode.service \
      /etc/xdg/autostart/ruscalinux-nvidia-settings-in-sistema.desktop \
      /usr/local/share/applications/nvidia-settings.desktop \
      /usr/share/keyrings/ruscalinux-nvidia-archive.gpg \
      /usr/lib/ruscalinux/driver-mode \
      /usr/lib/ruscalinux/nvidia-settings-in-sistema
rm -rf /usr/lib/ruscalinux/grub.d /usr/share/ruscalinux/nvidia
# Le copie di /etc/modprobe.d fatte dall'hook per neutralizzare il blacklist
# di nouveau non servono piu'.
for f in $(grep -l 'RuscaLinux, lo decide il menu di avvio' /etc/modprobe.d/*.conf 2> /dev/null); do
    rm -f "$f"
done
systemctl daemon-reload 2> /dev/null || true

update-initramfs -u -k all || true
rm -f /usr/lib/ruscalinux/nvidia-postinstall
EOF
chmod +x "$INC/usr/lib/ruscalinux/nvidia-postinstall"

cat <<'EOF' > "$INC/usr/lib/ruscalinux/grub.d/25_ruscalinux_free_drivers"
#!/bin/sh
# RuscaLinux — voce GRUB "free drivers" sul sistema installato con il driver
# NVIDIA: il kernel piu' recente, moduli NVIDIA esclusi e senza i parametri
# di GRUB_CMDLINE_LINUX (che escludono nouveau). Installato da
# /usr/lib/ruscalinux/nvidia-postinstall.
set -e
. /usr/share/grub/grub-mkconfig_lib

KERNEL=$(ls -1 /boot/vmlinuz-* 2> /dev/null | sort -V | tail -n 1)
[ -n "$KERNEL" ] || exit 0
VER=${KERNEL#/boot/vmlinuz-}
[ -f "/boot/initrd.img-$VER" ] || exit 0

if [ -n "$GRUB_DEVICE_UUID" ]; then
    RADICE="UUID=$GRUB_DEVICE_UUID"
else
    RADICE="$GRUB_DEVICE"
fi
BOOT=$(make_system_path_relative_to_its_root /boot)

echo "RuscaLinux, free drivers: $VER" >&2
echo "menuentry 'RuscaLinux with free drivers (without NVIDIA driver)' --class ruscalinux --class gnu-linux {"
prepare_grub_to_access_device "$GRUB_DEVICE_BOOT" | sed 's/^/\t/'
echo "	linux	$BOOT/vmlinuz-$VER root=$RADICE ro $GRUB_CMDLINE_LINUX_DEFAULT modprobe.blacklist=nvidia,nvidia_drm,nvidia_modeset,nvidia_uvm"
echo "	initrd	$BOOT/initrd.img-$VER"
echo "}"
EOF
chmod +x "$INC/usr/lib/ruscalinux/grub.d/25_ruscalinux_free_drivers"


# --- 6. nvidia-settings nella cartella Sistema -----------------------------
#
# GNOME Shell 48 crea le cartelle Sistema e Utilita' al primo accesso di ogni
# utente, scrivendo nelle sue impostazioni un elenco FISSO di applicazioni
# (js/ui/appDisplay.js, _ensureDefaultFolders). La cartella Sistema non usa
# le categorie del .desktop, quindi cambiare il file del pacchetto non basta;
# e un default dconf di sistema verrebbe sovrascritto da quell'elenco.
#
# Per questo uno script, avviato all'accesso, aggiunge nvidia-settings
# all'elenco DOPO che GNOME l'ha creato, una volta sola per utente e solo con
# il driver NVIDIA attivo: se l'utente sposta il pannello, resta dove l'ha
# messo.

cat <<'EOF' > "$INC/usr/lib/ruscalinux/nvidia-settings-in-sistema"
#!/bin/sh
# RuscaLinux — mette il pannello NVIDIA nella cartella Sistema di GNOME, una
# volta per utente. Scritto da steps/40-nvidia.sh; avviato da
# /etc/xdg/autostart/ruscalinux-nvidia-settings-in-sistema.desktop.

APP=nvidia-settings.desktop
CARTELLE=org.gnome.desktop.app-folders
SISTEMA=org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/System/
FATTO="${XDG_CONFIG_HOME:-$HOME/.config}/ruscalinux/nvidia-settings-in-sistema.fatto"

[ -e "$FATTO" ] && exit 0
grep -qw 'rusca.driver=nvidia' /proc/cmdline || exit 0   # driver liberi: niente pannello
[ "$(id -u)" -ge 1000 ] || exit 0                         # utenti di sistema (GDM, g-i-s)
[ -f "/usr/share/applications/$APP" ] || exit 0
command -v gsettings > /dev/null || exit 0

segna_fatto() {
    mkdir -p "$(dirname "$FATTO")"
    touch "$FATTO"
}

# Al primo accesso GNOME Shell crea le cartelle mentre parte: si aspetta
# che l'elenco esista (al massimo un minuto).
i=0
while [ "$(gsettings get "$CARTELLE" folder-children)" = "@as []" ]; do
    i=$((i + 1))
    [ "$i" -gt 60 ] && exit 0                      # si riprova al prossimo accesso
    sleep 1
done

# Se l'utente ha eliminato la cartella Sistema, la sua scelta si rispetta.
case "$(gsettings get "$CARTELLE" folder-children)" in
    *"'System'"*) ;;
    *) segna_fatto; exit 0 ;;
esac

APPS=$(gsettings get "$SISTEMA" apps)
case "$APPS" in
    *"'$APP'"*) ;;                                 # c'e' gia'
    "@as []")  gsettings set "$SISTEMA" apps "['$APP']" ;;
    *)         gsettings set "$SISTEMA" apps "${APPS%]}, '$APP']" ;;
esac

segna_fatto
EOF
chmod +x "$INC/usr/lib/ruscalinux/nvidia-settings-in-sistema"

cat <<'EOF' > "$INC/etc/xdg/autostart/ruscalinux-nvidia-settings-in-sistema.desktop"
[Desktop Entry]
Type=Application
Name=RuscaLinux NVIDIA settings folder
Comment=Puts the NVIDIA settings panel in the System folder, once per user
Exec=/usr/lib/ruscalinux/nvidia-settings-in-sistema
OnlyShowIn=GNOME;
NoDisplay=true
X-GNOME-Autostart-enabled=true
EOF
