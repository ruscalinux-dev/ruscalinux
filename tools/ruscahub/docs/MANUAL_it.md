# RuscaHub — Manuale utente

**Versione 1.99.2 · Suite RuscaTools · RuscaLinux**
Autore: Nunzio Curcuruto — © 2026 — Licenza GPL-3.0 — <https://www.ruscalinux.org/>

## 1. Panoramica
RuscaHub è il gestore ufficiale di AppImage di RuscaLinux. Permette di:
- importare file `.AppImage` tramite pulsante o trascinamento (drag & drop);
- archiviarli in una cartella nascosta della Home (`~/.ruscahub/apps/`);
- **installarli** (crea una voce nel menu GNOME con l'icona originale del programma);
- **disinstallarli** (rimuove solo la voce di menu);
- **avviarli** direttamente dall'elenco;
- **eliminarli** definitivamente (voce, icona e file).

## 2. Requisiti
- RuscaLinux o Debian Stable (o derivata) con ambiente GNOME;
- Python ≥ 3.10 con `python3-gi`, `python3-cairo`, `gir1.2-gtk-4.0`;
- consigliato `squashfs-tools`: permette di leggere nome e icona dell'AppImage
  **senza eseguirla** ed è il metodo più affidabile per ottenere l'icona corretta;
- consigliato FUSE 2 (`libfuse2t64` su Debian 13, `libfuse2` su Debian 12) per
  avviare le AppImage; in sua assenza RuscaHub ripiega automaticamente su
  `--appimage-extract-and-run`;
- per cinese, giapponese, coreano, hindi e arabo servono i relativi font
  (`fonts-noto-core`, `fonts-noto-cjk`), di norma già presenti in GNOME.

Il pacchetto `.deb` installa automaticamente le dipendenze e i pacchetti consigliati.

## 3. Installazione
### 3.1 Pacchetto .deb
Verifica dell'integrità, poi installazione:

    cd build-deb && sha256sum -c SHA256SUMS
    sudo apt install ./ruscahub-ruscalinux_1.99.2_all.deb

Il nome del pacchetto installato resta `ruscahub`: la nuova versione aggiorna
quella precedente senza conflitti.

### 3.2 Dai sorgenti

    python3 ruscahub.py

La cartella `lang/` deve trovarsi accanto a `ruscahub.py`.

## 4. Avvio
Dal menu GNOME: **RuscaHub** (categoria Utilità), oppure da terminale: `ruscahub`.

## 5. Finestra principale
- **Barra superiore (rosa):** pulsante «Aggiungi AppImage», indicatore di attività, pulsante Informazioni.
- **Elenco:** per ogni AppImage mostra icona, nome, percorso, stato
  («Installata» / «Archiviata») e i pulsanti Avvia, Installa/Disinstalla, Elimina.
- **Pagina vuota:** suggerimento per il trascinamento quando non ci sono AppImage archiviate.

## 6. Importare una AppImage
1. Trascina il file `.AppImage` sulla finestra, oppure premi «Aggiungi AppImage» e selezionalo
   (è possibile selezionarne più di uno).
2. RuscaHub copia il file in `~/.ruscahub/apps/`, imposta il permesso di esecuzione,
   ricava nome, descrizione e icona originali e lo aggiunge all'elenco.

### 6.1 Come viene trovata l'icona
Molte AppImage non contengono l'icona direttamente nella radice, ma un
collegamento simbolico verso una cartella interna. RuscaHub:
1. legge il file `.desktop` interno (anche se è un collegamento simbolico) e ne
   ricava `Name`, `Comment`, `Icon` e `StartupWMClass`;
2. segue il collegamento `.DirIcon` fino al file reale;
3. cerca l'icona indicata da `Icon=` nella radice, in `usr/share/icons/` e in
   `usr/share/pixmaps/`;
4. sceglie l'icona migliore: SVG (anche compresso `.svgz`) se disponibile,
   altrimenti il PNG di dimensione maggiore;
5. la salva in `~/.ruscahub/icons/`.

La lettura avviene con `unsquashfs`, senza eseguire l'AppImage; se non è
disponibile, RuscaHub usa il comando `--appimage-extract` dell'AppImage stessa.
Il contenuto dell'AppImage non viene mai modificato.

La chiave `StartupWMClass` collega la finestra del programma in esecuzione alla
sua voce di menu, così anche nella dash di GNOME compare l'icona corretta.

## 7. Operazioni disponibili
| Pulsante | Effetto |
|---|---|
| ▶ Avvia | Avvia subito l'AppImage |
| Installa | Crea la voce nel menu GNOME (`~/.local/share/applications/`) |
| Disinstalla | Rimuove la voce di menu, conserva il file |
| 🗑 Elimina | Cancella voce, icona, file `.desktop` e file AppImage |

## 8. Riparazione automatica delle icone
Le AppImage importate con versioni precedenti di RuscaHub e rimaste senza icona
vengono rianalizzate **una sola volta** al primo avvio della nuova versione:
l'indicatore di attività gira durante l'operazione. Se l'AppImage era installata,
la voce di menu viene riscritta con l'icona trovata.

## 9. File e percorsi
| Percorso | Contenuto |
|---|---|
| `~/.ruscahub/apps/` | AppImage archiviate |
| `~/.ruscahub/icons/` | Icone estratte |
| `~/.ruscahub/ruscahub.json` | Elenco persistente |
| `~/.local/share/applications/ruscahub-*.desktop` | Voci del menu GNOME |
| `/usr/share/ruscahub/lang/*.json` | Traduzioni dell'interfaccia |

## 10. Lingue supportate
RuscaHub è tradotto in 15 lingue:

| File | Lingua | File | Lingua |
|---|---|---|---|
| `en.json` | Inglese | `de.json` | Tedesco |
| `zh_CN.json` | Cinese semplificato | `fr.json` | Francese |
| `es.json` | Spagnolo | `it.json` | Italiano |
| `hi.json` | Hindi | `ko.json` | Coreano |
| `ar.json` | Arabo | `id.json` | Indonesiano |
| `pt_BR.json` | Portoghese brasiliano | `tr.json` | Turco |
| `ru.json` | Russo | `pl.json` | Polacco |
| `ja.json` | Giapponese | | |

- La lingua segue quella del sistema; per forzarla: `RUSCAHUB_LANG=de ruscahub`.
- Il cinese tradizionale (`zh_TW`, `zh_HK`) usa il cinese semplificato; il portoghese usa `pt_BR`.
- Con l'arabo l'interfaccia viene disposta da destra a sinistra.
- Se manca una traduzione si usa `en.json`; se manca anche lì il programma non
  si blocca e mostra il nome della chiave.
- Le traduzioni sono file JSON UTF-8 nella cartella `lang/`: per correggerle basta
  modificare il file della lingua.

## 11. Pannello Informazioni
Segue lo stile RuscaTools (barra rosa, gradiente rosa⇒prugna): nome, versione,
descrizione, autore, licenza, nota sul supporto IA e collegamento al sito.

## 12. Creazione del pacchetto .deb
Dalla radice del progetto:

    ./make-deb.sh

Risultato nella cartella `build-deb/`:
`ruscahub-ruscalinux_1.99.2_all.deb` + `SHA256SUMS`.
L'architettura è `all` perché RuscaHub è scritto interamente in Python.

## 13. Risoluzione dei problemi
- **Nel menu compare un'icona generica (rombo blu con ingranaggio):**
  installa `squashfs-tools` (`sudo apt install squashfs-tools`), poi premi
  «Disinstalla» e di nuovo «Installa». Le AppImage senza icona vengono
  comunque rianalizzate automaticamente al primo avvio della versione 1.99.2.
  Per controllare la voce: `grep Icon ~/.local/share/applications/ruscahub-*.desktop`.
- **Icona corretta nel menu ma generica nella dash mentre il programma è aperto:**
  l'AppImage non dichiara `StartupWMClass`; è un limite dell'AppImage, non di RuscaHub.
- **L'AppImage non si avvia:** installa `libfuse2t64` (Debian 13) o `libfuse2`
  (Debian 12); altrimenti RuscaHub usa il ripiego automatico.
- **La voce di menu non compare:** esci e rientra nella sessione, oppure esegui
  `update-desktop-database ~/.local/share/applications`.
- **Una voce è sparita dall'elenco:** il file è stato spostato manualmente; all'avvio
  RuscaHub rimuove automaticamente le voci orfane.
- **Caratteri a quadratini in cinese, giapponese, coreano, hindi o arabo:**
  installa `fonts-noto-core` e `fonts-noto-cjk`.

## 14. Privacy e sicurezza
Tutti i dati elaborati da RuscaHub rimangono in locale. Nessun dato o file viene
inviato a server remoti o su internet; non c'è telemetria. RuscaHub non contiene
comandi pericolosi o dannosi per il sistema operativo: l'unica operazione
distruttiva (Elimina) agisce solo sui file creati da RuscaHub stesso ed è avviata
esplicitamente dall'utente.

## 15. Nota di sviluppo
Sviluppato con il supporto di strumenti AI: progettazione, specifiche,
revisione e responsabilità editoriale sono dell'autore.

## 16. Licenza e contatti
GPL-3.0 — Nunzio Curcuruto (ruscalinux-dev) — <info@ruscalinux.org>
