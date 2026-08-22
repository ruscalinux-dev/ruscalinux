# Come funziona questo repository

Manuale per chi mantiene RuscaLinux. Il [README](README.md) è la vetrina per
chi arriva da fuori; qui c'è tutto il resto.

Tre script, in ordine di utilizzo. Nessuno di essi decide *cosa* c'è dentro la
ISO: quello lo decidono i tre file in `steps/`.

| | |
|---|---|
| `release.conf` | Le impostazioni. **L'unico file dove è scritta la versione.** |
| `make-debs.sh` | Costruisce i pacchetti `.deb` da `branding/` e `tools/`. |
| `build.sh` | Costruisce la ISO. |
| `test.sh` | La avvia in QEMU per provarla. |

## Fare una nuova versione

```sh
vi release.conf     # VERSION="2.0"
./build.sh
./test.sh
```

Poi si pubblica a mano: vedi più sotto.

Il numero di versione si scrive una volta sola. Da `release.conf` finisce nel
nome della ISO, nell'etichetta del volume, in `/etc/os-release`, in
`/etc/issue`, nel titolo dell'installer e nella sua immagine: sono i diciassette
punti dove prima andava scritto a mano.

## Cosa serve sulla macchina

```sh
sudo apt install live-build wget qemu-system-x86 qemu-utils ovmf
```

`wget` serve a scaricare RuscaWriter dal suo repository. Debian lo installa di
serie, ma su un sistema ridotto all'osso potrebbe mancare.

## Cosa fa build.sh, in ordine

1. Controlla che ci siano `live-build` e `wget`, e che tu non sia root.
2. Se manca `local/extra_debs/`, lancia `make-debs.sh`.
3. Verifica che ci siano RuscaWriter e ogni utility di `tools/`.
4. Copia `steps/*.sh` in `.gen/` sostituendo `@VERSION@` col numero vero.
5. Esegue i tre step, che preparano `.work/`.
6. Lancia `lb build` e calcola lo sha256 della ISO.

7. Riempie i documenti del rilascio col nome del file, il peso, lo sha256 e il
   numero di pacchetti veri: `RELEASE-NOTES-<versione>.md` dal modello
   `RELEASE-NOTES.md`, e `README.md` e `INSTALL.md` dai modelli in `dist/`.

`./build.sh --config` si ferma dopo il punto 5: utile per controllare la
configurazione senza aspettare la build lunga.
`./build.sh --clean` cancella `.work` e `.gen` e basta.

## Le cartelle

| | |
|---|---|
| `steps/` | **I tre script che determinano la ISO.** Sono i tuoi. |
| `branding/` | Sorgenti: logo, icone, sfondi, caratteri, generatori HTML. |
| `tools/` | Le applicazioni di RuscaLinux, una cartella ciascuna. |
| `local/` | File che live-build usa direttamente (splash, logo). |
| `vendor/` | Copia di scorta di RuscaWriter, per costruire senza rete. |
| `.work/` | Dove lavora live-build. Si rigenera, non sta in git. |
| `.gen/` | Gli script di `steps/` col numero di versione dentro. |

## Aggiungere un'applicazione

Crea `tools/<nome>/` con dentro:

- un file `VERSION` che contiene solo il numero, per esempio `1.0`
- uno script `make-<nome>-deb.sh` che riceve la versione come primo argomento
  e scrive un `.deb` nella cartella corrente

Nient'altro. `make-debs.sh` scorre `tools/*/` e costruisce quello che trova;
`build.sh` pretende poi un pacchetto con quel nome e si ferma se manca.
Nessuno script nomina le applicazioni, quindi aggiungerne una non richiede
di modificare niente.

## Da dove arriva RuscaWriter

Non si costruisce qui: ha un repository suo. `make-debs.sh` scarica l'ultima
release pubblicata e ne verifica il checksum. In questo repository non è
scritto da nessuna parte quale versione sia: quella pubblicata è quella che
finisce nella ISO. Una copia resta in `vendor/` per poter costruire senza rete.

## Pubblicare

Tutto a mano. Sono quattro passi, un paio di volte l'anno.

**1. SourceForge** — <https://sourceforge.net/projects/ruscalinux/files/>
Crea la cartella con il numero di versione e caricaci dentro i cinque file che
`build.sh` ha lasciato in `.work/`:

- la ISO
- `SHA256SUMS`
- `ruscalinux-<versione>-amd64.packages` (l'elenco dei pacchetti installati)
- `README.md` e `INSTALL.md` (le istruzioni per chi scarica)

Poi imposta la ISO come download predefinito per Linux.

**2. Git**

```sh
git add -A
git commit -m "Release 2.0"
git tag -a v2.0 -m "RuscaLinux 2.0"
git push origin main --tags
```

**3. GitHub** — <https://github.com/ruscalinux-dev/ruscalinux/releases/new>
Tag `v2.0`, titolo `RuscaLinux 2.0`, e nel testo incolla il contenuto di
`RELEASE-NOTES-2.0.md`. Allega `SHA256SUMS`, non la ISO: quella sta su
SourceForge.

**4. Sito** — aggiorna versione, nome del file e sha256 nella pagina download.

Il checksum **copialo**, non riscriverlo: sta in `RELEASE-NOTES-2.0.md` ed è
lungo 64 caratteri. Se lo sbagli, la verifica fallisce a chiunque scarichi e
non ricevi alcun segnale — te lo dice solo qualcuno che scrive per lamentarsi.

## I documenti per chi scarica

`dist/README.md` e `dist/INSTALL.md` sono i due file pubblicati su SourceForge
accanto alla ISO. Sono **modelli**: al posto della versione, del nome del file,
del checksum e del numero di pacchetti contengono `@VERSION@`, `@ISO@`,
`@SHA256@` e `@PACCHETTI@`, che `build.sh` sostituisce con i valori veri.

Erano ventitré punti da correggere a mano a ogni rilascio, in due lingue. Ora
si modificano solo quando cambia il *contenuto* — un'applicazione aggiunta,
una sezione riscritta — mai per un cambio di versione.

Il numero di pacchetti non è scritto da nessuna parte: lo conta `build.sh` dal
file `.packages` che live-build produce insieme alla ISO.

## Le novità di ogni versione

Prima di lanciare `build.sh`, apri `RELEASE-NOTES.md` e riscrivi la sezione
**Highlights**. È l'unica parte scritta a mano: versione, nome del file, peso,
checksum e data li mette `build.sh`, quindi le note non possono mai
contraddire la ISO che hai davvero costruito.
