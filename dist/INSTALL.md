# INSTALL — RuscaLinux @VERSION@

**English** | [Italiano](#installazione-italiano)

---

## Installation (English)

### 1. Download

Get `@ISO@` from the SourceForge files page or from
the official website at https://www.ruscalinux.org.

### 2. Verify the checksum

This step is short, free, and prevents you from installing a corrupted or
tampered file.

The official SHA256 hash for @VERSION@ is:

```
@SHA256@
```

**Linux / macOS:**

```sh
sha256sum @ISO@
```

Compare the output to the hash above. The two strings must be identical.
Alternatively, with the `SHA256SUMS` file next to the ISO:

```sh
sha256sum -c SHA256SUMS
```

**Windows (PowerShell):**

```powershell
Get-FileHash @ISO@ -Algorithm SHA256
```

### 3. Write the ISO to a USB stick

You need a USB drive of 4 GB or more. **The drive will be erased.**

**Easiest path (any OS) — balenaEtcher:**
download from https://www.balena.io/etcher/, open it, select the ISO, select
the USB drive, click Flash.

**Linux / macOS — command line:**

```sh
sudo dd if=@ISO@ of=/dev/sdX bs=4M status=progress oflag=sync
```

Replace `/dev/sdX` with your USB device (find it with `lsblk` on Linux, or
`diskutil list` on macOS). **Double-check** before pressing Enter: `dd`
overwrites the target without asking.

### 4. Boot from USB

Insert the USB stick, restart the computer, and enter the boot menu. The key
depends on the manufacturer — usually F12, F11, F10, F9, F2, ESC, or DEL.
Select the USB drive.

### 5. Try, then install

You'll see the RuscaLinux boot menu:

| Option | What it does |
|---|---|
| **Live system (@ARCH@)** | Runs RuscaLinux entirely from the USB stick. Nothing is written to your disk. The best way to try the system first. |
| **Live system (@ARCH@) with NVIDIA driver** | Same, with the NVIDIA driver instead of the free drivers. See [NVIDIA graphics cards](#nvidia-graphics-cards). |
| **Live system (amd64 fail-safe mode)** | Same, with safer driver options if the default mode doesn't display correctly. |
| **Start installer** | Install RuscaLinux on your computer, with the free graphics drivers. |
| **Start installer with NVIDIA driver** | Install RuscaLinux with the NVIDIA driver active. |
| **Start installer with speech synthesis** | Accessible, spoken installation. |
| **Advanced install options** | For experienced users. |
| **Utilities** | Memory test and other tools. |

The installer is graphical and walks you through language, keyboard, disk
partitioning, user creation, and final installation. Allow 15–30 minutes
depending on disk speed.

### 6. After installation

Remove the USB stick when prompted, reboot, and log in with the user you
created. The system is **ready to use** — office, multimedia, browser, and
email are already installed and configured.

---

## NVIDIA graphics cards

RuscaLinux starts and installs with the **free graphics drivers**, which work
on every computer. The image also contains the **NVIDIA driver @NVIDIA@**,
which gives NVIDIA cards their full speed: choose it with the
**“… with NVIDIA driver”** entries of the boot menu.

It works with **GTX 16, RTX 20 and later** cards (RTX 30, 40, 50), desktop
and laptop. Older cards (GTX 900, GTX 1000) use the free drivers.

**Try it first.** Start **Live system (@ARCH@) with NVIDIA driver**. If the
desktop works, install with **Start installer with NVIDIA driver**.

**Laptops with two graphics cards.** The desktop runs on the integrated
graphics and the NVIDIA card turns on only for the programs that ask for
it: right-click an application and choose “Launch using Dedicated Graphics
Card”.

**The choice is made once, at installation.** Installing with the free
drivers removes the NVIDIA driver from the installed system; to use it
later, reinstall with **Start installer with NVIDIA driver**. If you install
with the NVIDIA driver and it causes problems, the boot menu of the
installed system has the entry **“RuscaLinux with free drivers (without
NVIDIA driver)”**.

### Secure Boot

With Secure Boot on, the computer loads the NVIDIA driver only after you
enroll the RuscaLinux certificate. You do this **once per computer**, from
the live session with the NVIDIA driver or from the installed system:

```sh
sudo mokutil --import /usr/share/ruscalinux/nvidia/ruscalinux-mok.der
```

1. `mokutil` asks for a password: choose one, you will need it only once.
2. Restart. A blue screen appears, **MokManager**.
3. Choose **Enroll MOK → Continue → Yes**, type the password, then
   **Reboot**.

Until the certificate is enrolled, the NVIDIA entries still start, but the
desktop uses the integrated graphics (laptops) or basic graphics without
acceleration (desktops). As an alternative you can turn Secure Boot off in
the firmware settings. On **Acer** laptops the Secure Boot option stays
grey until you set a supervisor password in the Security tab (F2 at
power-on).

**About the licence.** The NVIDIA driver is proprietary software, distributed
under the NVIDIA licence; its kernel modules are open source. The free
drivers remain the default.

---

## A note on updates

RuscaLinux has no live repositories. Your system will not download anything in
the background, and nothing will silently change under you.

To move to a newer release, download the new ISO from SourceForge or the
official website, verify it, and install it fresh. Each version is a complete,
known starting point.

This includes security fixes: they arrive with each new release. The same
goes for the NVIDIA driver, whose version (@NVIDIA@) is written in the
release notes.

---

## Need help?

- Website: https://www.ruscalinux.org
- YouTube: https://www.youtube.com/@ruscalinux
- Email: info@ruscalinux.org

---
---

## Installazione (Italiano)

### 1. Scarica

Scarica `@ISO@` dalla pagina dei file di SourceForge
o dal sito ufficiale https://www.ruscalinux.org.

### 2. Verifica il checksum

Un passaggio veloce, gratuito, e che ti evita di installare un file corrotto
o manomesso.

L'hash SHA256 ufficiale per la @VERSION@ è:

```
@SHA256@
```

**Linux / macOS:**

```sh
sha256sum @ISO@
```

Confronta il risultato con l'hash qui sopra. Le due stringhe devono essere
identiche. In alternativa, con il file `SHA256SUMS` accanto alla ISO:

```sh
sha256sum -c SHA256SUMS
```

**Windows (PowerShell):**

```powershell
Get-FileHash @ISO@ -Algorithm SHA256
```

### 3. Scrivi la ISO su una chiavetta USB

Serve una chiavetta da almeno 4 GB. **Sarà completamente cancellata.**

**Modo più semplice (qualsiasi sistema) — balenaEtcher:**
scarica da https://www.balena.io/etcher/, aprilo, seleziona la ISO, seleziona
la chiavetta, clicca Flash.

**Linux / macOS — riga di comando:**

```sh
sudo dd if=@ISO@ of=/dev/sdX bs=4M status=progress oflag=sync
```

Sostituisci `/dev/sdX` con la tua chiavetta (la trovi con `lsblk` su Linux o
`diskutil list` su macOS). **Controlla due volte** prima di premere Invio:
`dd` sovrascrive la destinazione senza chiedere.

### 4. Avvia da USB

Inserisci la chiavetta, riavvia il computer ed entra nel menu d'avvio. Il
tasto dipende dal produttore — di solito F12, F11, F10, F9, F2, ESC o CANC.
Seleziona la chiavetta USB.

### 5. Prova, poi installa

Apparirà il menu d'avvio di RuscaLinux:

| Opzione | Cosa fa |
|---|---|
| **Live system (@ARCH@)** | Avvia RuscaLinux interamente dalla chiavetta. Nulla viene scritto sul disco. Il modo migliore per provare il sistema. |
| **Live system (@ARCH@) with NVIDIA driver** | Come sopra, con il driver NVIDIA al posto dei driver liberi. Vedi [Schede grafiche NVIDIA](#schede-grafiche-nvidia). |
| **Live system (amd64 fail-safe mode)** | Stesso modo, con driver più conservativi se il sistema non viene visualizzato correttamente. |
| **Start installer** | Installa RuscaLinux sul computer, con i driver grafici liberi. |
| **Start installer with NVIDIA driver** | Installa RuscaLinux con il driver NVIDIA attivo. |
| **Start installer with speech synthesis** | Installazione parlata e accessibile. |
| **Advanced install options** | Per utenti esperti. |
| **Utilities** | Test della memoria e altri strumenti. |

L'installer è grafico e ti guida attraverso lingua, tastiera, partizionamento
del disco, creazione utente e installazione finale. Richiede 15–30 minuti a
seconda della velocità del disco.

### 6. Dopo l'installazione

Rimuovi la chiavetta quando richiesto, riavvia, e accedi con l'utente che hai
creato. Il sistema è **già pronto all'uso** — ufficio, multimedia, browser e
posta sono già installati e configurati.

---

## Schede grafiche NVIDIA

RuscaLinux si avvia e si installa con i **driver grafici liberi**, che
funzionano su ogni computer. La ISO contiene anche il **driver NVIDIA
@NVIDIA@**, che dà alle schede NVIDIA tutte le loro prestazioni: si sceglie
con le voci **“… with NVIDIA driver”** del menu di avvio.

Funziona con le schede **GTX 16, RTX 20 e successive** (RTX 30, 40, 50), sia
desktop sia portatili. Le schede precedenti (GTX 900, GTX 1000) usano i
driver liberi.

**Prima prova.** Avvia **Live system (@ARCH@) with NVIDIA driver**. Se il
desktop funziona, installa con **Start installer with NVIDIA driver**.

**Portatili con due schede grafiche.** Il desktop usa la grafica integrata e
la scheda NVIDIA si accende solo per i programmi che la chiedono: clic
destro su un'applicazione e “Avvia usando la scheda grafica dedicata”.

**La scelta si fa una volta, all'installazione.** Installando con i driver
liberi, il driver NVIDIA viene tolto dal sistema installato; per usarlo in
seguito si reinstalla con **Start installer with NVIDIA driver**. Se installi
con il driver NVIDIA e dà problemi, nel menu di avvio del sistema installato
c'è la voce **“RuscaLinux with free drivers (without NVIDIA driver)”**.

### Secure Boot

Con Secure Boot attivo, il computer carica il driver NVIDIA solo dopo che hai
registrato il certificato di RuscaLinux. Si fa **una volta per computer**,
dalla sessione live con il driver NVIDIA o dal sistema installato:

```sh
sudo mokutil --import /usr/share/ruscalinux/nvidia/ruscalinux-mok.der
```

1. `mokutil` chiede una password: scegline una, servirà una volta sola.
2. Riavvia. Compare una schermata blu, **MokManager**.
3. Scegli **Enroll MOK → Continue → Yes**, scrivi la password, poi
   **Reboot**.

Finché il certificato non è registrato, le voci NVIDIA partono lo stesso, ma
il desktop usa la grafica integrata (portatili) o una grafica di base senza
accelerazione (desktop). In alternativa puoi disattivare Secure Boot nelle
impostazioni del firmware. Sui portatili **Acer** l'opzione Secure Boot resta
grigia finché non imposti una password supervisore nella scheda Security (F2
all'accensione).

**Sulla licenza.** Il driver NVIDIA è software proprietario, distribuito con
la licenza NVIDIA; i suoi moduli del kernel sono open source. I driver
liberi restano quelli predefiniti.

---

## Una nota sugli aggiornamenti

RuscaLinux non ha repository attivi. Il sistema non scaricherà nulla in
background e nulla cambierà in silenzio sotto di te.

Per passare a una nuova release scarica la nuova ISO da SourceForge o dal
sito ufficiale, verificala, e installala da zero. Ogni versione è un punto
di partenza completo e conosciuto.

Vale anche per le correzioni di sicurezza: arrivano con ogni nuova release.
Lo stesso per il driver NVIDIA, la cui versione (@NVIDIA@) è scritta nelle
note di rilascio.

---

## Aiuto

- Sito: https://www.ruscalinux.org
- YouTube: https://www.youtube.com/@ruscalinux
- Email: info@ruscalinux.org
