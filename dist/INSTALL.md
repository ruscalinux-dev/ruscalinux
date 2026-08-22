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
| **Live system (amd64 fail-safe mode)** | Same, with safer driver options if the default mode doesn't display correctly. |
| **Start installer** | Install RuscaLinux on your computer. |
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

## A note on updates

RuscaLinux has no live repositories. Your system will not download anything in
the background, and nothing will silently change under you.

To move to a newer release, download the new ISO from SourceForge or the
official website, verify it, and install it fresh. Each version is a complete,
known starting point.

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
| **Live system (amd64 fail-safe mode)** | Stesso modo, con driver più conservativi se il sistema non viene visualizzato correttamente. |
| **Start installer** | Installa RuscaLinux sul computer. |
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

## Una nota sugli aggiornamenti

RuscaLinux non ha repository attivi. Il sistema non scaricherà nulla in
background e nulla cambierà in silenzio sotto di te.

Per passare a una nuova release scarica la nuova ISO da SourceForge o dal
sito ufficiale, verificala, e installala da zero. Ogni versione è un punto
di partenza completo e conosciuto.

---

## Aiuto

- Sito: https://www.ruscalinux.org
- YouTube: https://www.youtube.com/@ruscalinux
- Email: info@ruscalinux.org
