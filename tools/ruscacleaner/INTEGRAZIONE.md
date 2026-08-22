# Integrare RuscaCleaner in RuscaLinux

Scritto dopo aver letto il repository: Debian trixie, GNOME 48, `live-build`,
pacchetti `.deb` generati da `make-debs.sh` in `local/extra_debs/` e copiati
in `packages.chroot/` da `steps/30-custom.sh`.

RuscaCleaner segue lo stesso percorso di `adwaita-prugna` e degli sfondi: è un
pacchetto costruito in casa, non un componente scaricato come RuscaWriter.

---

## 1. Dove mettere i sorgenti

RuscaWriter vive in un repository separato perché è un'applicazione con vita
propria. RuscaCleaner è quattrocento righe che riguardano solo questo sistema:
tenerlo qui evita un secondo repository, un secondo ciclo di release e un
secondo numero di versione da tenere allineato.

```
ruscalinux/
├── tools/
│   └── ruscacleaner/
│       ├── ruscacleaner.py
│       ├── ruscacleaner.svg
│       ├── ruscacleaner.desktop
│       ├── org.ruscalinux.RuscaCleaner.metainfo.xml
│       └── make-ruscacleaner-deb.sh
```

`tools/` è sorgente, come `branding/`. L'output resta in `local/extra_debs/`,
che è già in `.gitignore`.

Va aggiunta una riga a `.gitignore`? No: il `.deb` finisce dove finiscono gli
altri.

## 2. Agganciarlo a `make-debs.sh`

Un blocco dopo quello dei font, nello stesso stile degli altri:

```sh
step "RuscaCleaner"
bash "$HERE/tools/ruscacleaner/make-ruscacleaner-deb.sh" "$RUSCACLEANER_VERSION" >/dev/null
ok "ruscacleaner"
```

E in `release.conf`, accanto a `BRANDING_VERSION`:

```sh
# --- Strumenti di sistema ---------------------------------------------------
RUSCACLEANER_VERSION="1.0"
```

`build.sh` chiama `make-debs.sh` quando `local/extra_debs/` è vuota, quindi non
serve altro: il pacchetto viene costruito, copiato in `packages.chroot/` dalla
riga 6 di `steps/30-custom.sh` e installato durante il chroot.

Il commento a quella riga elenca i pacchetti copiati (`adwaita-prugna,
ruscalinux-backgrounds-it`): aggiungerci `ruscacleaner` costa una parola e
mantiene vera l'unica documentazione che quella riga ha.

## 3. Dipendenze

`steps/20-packages.sh` non contiene `python3-gi` né alcun `gir1.2-*`:
RuscaWriter se li porta dietro con il proprio campo `Depends`. RuscaCleaner fa
lo stesso, con una voce in più:

```
Depends: python3, python3-gi, gir1.2-gtk-4.0, gir1.2-adw-1
```

`gir1.2-adw-1` è il pacchetto che va aggiunto e che nessun altro tira dentro:
è il typelib di libadwaita, separato dalla libreria che GNOME installa già.
Senza, l'app fallisce all'import con un errore di namespace.

Su trixie libadwaita è la 1.7, quindi `Adw.AlertDialog` (1.5) è disponibile.
Il docstring del sorgente però dichiara ancora 1.4, che è la versione di
`Adw.SwitchRow` ma non basta per il dialogo di conferma: va corretto a 1.5.

## 4. Il colore d'accento

Questo è il punto che cambia di più l'aspetto del risultato.

`steps/30-custom.sh` scrive nella gschema override:

```
[org.gnome.desktop.interface]
icon-theme='Adwaita-Prugna'
accent-color='slate'
```

Il CSS di `ruscacleaner.py` invece forza:

```css
@define-color accent_bg_color #7d3c68;
--accent-color: #a4508b;
```

RuscaCleaner sarebbe l'unica finestra del sistema a ignorare l'accento che la
distribuzione stessa imposta — e a ignorarlo anche dopo che l'utente lo ha
cambiato nelle impostazioni, cosa che su GNOME 48 è una preferenza di primo
livello. Vanno tolte le tre `@define-color` e il blocco `:root`.

Il gradiente `.rusca-hero` invece può restare: è decorazione dentro la finestra,
non un override del tema. Anche `.rusca-total`, che usa `#a4508b` come colore
del testo, andrebbe legato a `var(--accent-color)` così segue l'accento di
sistema invece di contraddirlo.

## 5. L'icona nel dock (riguarda anche RuscaWriter)

`ruscacleaner.py` dichiara `APP_ID = "io.github.ruscacleaner.RuscaCleaner"`. Va
portato a `org.ruscalinux.RuscaCleaner`, per coerenza con
`org.ruscalinux.RuscaWriter` in `editor.py`.

C'è però un dettaglio che vale la pena verificare su RuscaWriter, perché lo
stesso problema si riprodurrebbe qui. GTK4 su Wayland usa l'`application_id`
come `app_id` della finestra, e GNOME Shell cerca un file `.desktop` con
quel nome esatto. Con `application_id = org.ruscalinux.RuscaWriter` e un file
chiamato `ruscawriter.desktop`, l'abbinamento non riesce per nome: la finestra
può comparire nel dock come voce separata, senza icona e senza nome
applicazione.

Due modi per risolverlo, entrambi corretti:

- rinominare il `.desktop` in `org.ruscalinux.RuscaCleaner.desktop` (e l'icona
  di conseguenza), che è la convenzione GNOME moderna;
- oppure tenere il nome breve e aggiungere una riga:
  `StartupWMClass=org.ruscalinux.RuscaCleaner`.

Il `.desktop` allegato usa la seconda, per non rompere l'uniformità con
`ruscawriter.desktop`. Se RuscaWriter non ha quella riga, gli serve.

## 6. Esecuzione con sudo

`Path.home()` sotto `sudo` restituisce `/root`. L'app pulirebbe la home
sbagliata senza dire nulla, e all'utente sembrerebbe semplicemente che non
abbia funzionato. Poche righe all'avvio:

```python
import os, sys
if os.geteuid() == 0 and os.environ.get("SUDO_USER"):
    print("RuscaCleaner lavora sulla tua cartella personale: non usare sudo.",
          file=sys.stderr)
    sys.exit(1)
```

## 7. Lingua — fatto

Le trentadue stringhe italiane erano scritte nel codice. Ora stanno in
`lang/<codice>.json`, lo stesso schema di `usr/share/ruscawriter/lang/`.

Sette lingue complete: italiano, inglese, spagnolo, francese, tedesco,
portoghese, russo — le stesse che `i18n.py` di RuscaWriter elenca in
`COMPLETE_LANGUAGES`. Per aggiungerne una basta copiare `en.json`, tradurre
i valori e lasciare le chiavi.

Una differenza voluta rispetto a RuscaWriter: qui **non c'è un selettore di
lingua**. RuscaWriter ne ha bisogno perché la lingua dell'interfaccia e quella
in cui scrivi sono scelte separate; un pulisci-cache invece segue il sistema e
basta. La lingua viene da `GLib.get_language_names()`, con l'inglese come
ripiego per le chiavi mancanti e la chiave stessa come ultima difesa — così un
file di traduzione incompleto degrada invece di far crashare l'app.

Provato con `it_IT`, `de_DE`, `ru_RU`, `en_GB`, un locale senza traduzione
(`ja_JP`) e `LANG=C`: gli ultimi tre ripiegano correttamente sull'inglese.

Tradotta anche la voce di menu: `GenericName`, `Comment` e `Keywords` nelle
stesse sette lingue, così la ricerca di GNOME trova l'app scrivendo
"Papierkorb" o "corbeille" e non solo "cestino".

Nota su una riga che è stata riscritta: `_scan_done` costruiva il messaggio
di registro con `self.total_label.get_label().lower()`, cioè riusava
l'etichetta dell'interfaccia abbassandone le maiuscole. In tedesco quella
minuscola forzata è un errore ortografico — i sostantivi vanno maiuscoli — e
in russo o giapponese l'operazione non ha senso. Ora il messaggio ha una
chiave propria, `scan_done`, con il segnaposto `{size}`.

## 8. Sessione live

Nella sessione live la home è un tmpfs che sparisce al riavvio: pulirla non
libera spazio su disco e non protegge nulla. Non è un problema di sicurezza,
ma l'app promette un risultato che lì non può mantenere.

Se vuoi nasconderla in live, la stessa tecnica già usata in `30-custom.sh` per
gli autostart funziona: lo script `live-config` scrive nella overlay di
sessione un file

```
/usr/share/applications/ruscacleaner.desktop
```

con `Hidden=true`, che il sistema installato non eredita.

---

## Cosa è stato preparato

| File | Dove va |
|---|---|
| `ruscacleaner.py` | `tools/ruscacleaner/` — sorgente con i18n e guardia sudo |
| `lang/*.json` | `tools/ruscacleaner/lang/` — sette lingue |
| `ruscacleaner.svg` | `tools/ruscacleaner/` |
| `ruscacleaner.desktop` | `tools/ruscacleaner/` |
| `org.ruscalinux.RuscaCleaner.metainfo.xml` | `tools/ruscacleaner/` |
| `make-ruscacleaner-deb.sh` | `tools/ruscacleaner/` |

Nel sorgente sono già applicati: il blocco i18n, `APP_ID` a
`org.ruscalinux.RuscaCleaner` (necessario perché `StartupWMClass` corrisponda) e
il rifiuto di partire sotto `sudo`. **Non** è stato toccato il CSS: la
rimozione delle `@define-color` descritta al punto 4 resta da decidere.

Lo script è stato provato: produce `ruscacleaner_1.0-1~ruscalinux1_all.deb`
(232 KB) con launcher in `/usr/bin`, applicazione e `lang/` in
`/usr/share/ruscacleaner/`,
icone da 16 a 512 px più la scalable, pagina man, `copyright` in formato
DEP-5 e changelog compresso — la stessa struttura del pacchetto RuscaWriter.
`desktop-file-validate` passa senza avvisi.

Richiede `librsvg2-bin` per generare i PNG dall'SVG. Senza, il pacchetto si
costruisce lo stesso ma con la sola icona scalable, e GNOME Shell la
rasterizza male a 32 px.
