# Manuale di RuscaMark 1.99.2

RuscaMark è l'editor Markdown dei RuscaLinux OS Tools. È pensato per scrivere articoli, report, appunti e documentazione: la formattazione compare mentre scrivi, la pagina resta centrata come un foglio e tutto il lavoro avviene sul tuo computer.

| Campo | Valore |
|---|---|
| Versione | 1.99.2 |
| Autore | Nunzio Curcuruto (ruscalinux-dev) |
| Sito web | [ruscalinux.org](https://ruscalinux.org) |
| Contatto | info@ruscalinux.org |
| Licenza | GPL-3.0 — <https://www.gnu.org/licenses/gpl-3.0.html> |

---

## 1. Requisiti e installazione

| Requisito | Valore |
|---|---|
| Sistema | RuscaLinux o Debian Stable |
| Desktop | GNOME (funziona anche in altri ambienti GTK 4) |
| Toolkit | GTK 4 |
| Linguaggio | Python 3.10 o successivo |

Prima di installare, verifica l'integrità del pacchetto nella cartella che contiene il file `SHA256SUMS`:

```bash
sha256sum -c SHA256SUMS
```

Installazione consigliata:

```bash
sudo apt install ./ruscamark-ruscalinux_1.99.2_all.deb
```

In alternativa `sudo dpkg -i ruscamark-ruscalinux_1.99.2_all.deb`, seguito da `sudo apt -f install` se mancano dipendenze.

Pacchetti consigliati (installati automaticamente da `apt` se disponibili):

| Pacchetto | A cosa serve |
|---|---|
| `gir1.2-gtksource-5` | Editor avanzato: annulla/ripeti, ricerca evidenziata |
| `gir1.2-spelling-1` | Controllo ortografico live |
| `hunspell-it`, `hunspell-en-gb` | Dizionari italiano e inglese britannico |

Per altre lingue installa il dizionario corrispondente, ad esempio `hunspell-fr` o `hunspell-de-de`.

## 2. Avvio

Apri RuscaMark dal menu applicazioni di GNOME oppure cercandolo in Attività. Da terminale:

```bash
ruscamark                 # documento di benvenuto
ruscamark relazione.md    # apre un file
```

Puoi anche trascinare un file `.md` dentro la finestra.

## 3. La finestra

- **Barra superiore**: a sinistra Nuovo, Apri e Salva; a destra il menu principale, l'anteprima, il controllo ortografico e lo schermo intero.
- **Pagina di scrittura**: il testo occupa una colonna centrata, larga quanto impostato nelle Preferenze (68 caratteri di default). I margini si ricalcolano quando ridimensioni, massimizzi o metti a schermo intero la finestra, e quando apri l'anteprima.
- **Barra di stato**: parole, caratteri e righe, posizione del cursore e obiettivo di parole.
- **Barra ortografia**: compare sotto il testo quando accendi il controllo ortografico.

## 4. Due modi di vedere il testo

**Resa live (Ctrl+L)** — modalità predefinita. Titoli, grassetti, corsivi, codice, link, citazioni ed elenchi assumono subito il loro aspetto e i marcatori (`**`, `#`, `>`…) si nascondono. Quando porti il cursore su un elemento, la sua sintassi riappare per poterla modificare. Le tabelle restano in carattere monospazio, così le colonne allineate rimangono incolonnate.

**Anteprima classica (Ctrl+P)** — divide la finestra: a sinistra il sorgente con la sintassi colorata, a destra il documento impaginato. Solo l'anteprima mostra le immagini vere, le tabelle disegnate a griglia e le note raccolte in fondo. Con il tema chiaro l'anteprima usa gli stessi colori dell'export PDF e HTML; con il tema scuro resta prugna.

Le due modalità si escludono: accendendone una, l'altra si spegne.

## 5. Guida rapida al Markdown

### Testo

| Scrivi | Ottieni |
|---|---|
| `**grassetto**` o `__grassetto__` | **grassetto** |
| `*corsivo*` o `_corsivo_` | *corsivo* |
| `***entrambi***` | ***entrambi*** |
| `~~barrato~~` | ~~barrato~~ |
| `==evidenziato==` | testo evidenziato |
| `` `codice` `` | `codice` |
| `\*non corsivo\*` | \*non corsivo\* (il backslash annulla il marcatore) |

Per andare a capo senza iniziare un nuovo paragrafo, termina la riga con due spazi oppure con `\`. Una riga vuota separa i paragrafi.

### Titoli

```markdown
# Titolo di livello 1
## Titolo di livello 2
###### Titolo di livello 6

Titolo alternativo di livello 1
===============================

Titolo alternativo di livello 2
-------------------------------
```

Nell'HTML esportato ogni titolo riceve un'ancora (`id`), utile per i link interni come `[vai ai risultati](#risultati)`.

### Elenchi

```markdown
- punto
- altro punto
  - punto annidato (rientro di due spazi)

1. primo
2. secondo

3. un elenco può iniziare da qualsiasi numero
```

Liste di attività:

```markdown
- [x] bozza completata
- [ ] revisione
```

### Citazioni

```markdown
> Una citazione può occupare più righe
> e contenere **formattazione**.
>
> > Citazioni annidate con più `>`.
```

### Link

```markdown
[testo del link](https://ruscalinux.org "titolo facoltativo")
<https://ruscalinux.org>
https://ruscalinux.org          (gli indirizzi nudi diventano link)

Link a riferimento: vedi [Debian][deb].

[deb]: https://debian.org "Debian"
```

I link a riferimento tengono pulito il testo degli articoli lunghi: le definizioni possono stare in fondo al documento.

### Immagini

```markdown
![Descrizione dell'immagine](img/grafico.png "titolo facoltativo")
```

- Il percorso può essere relativo alla cartella del documento (consigliato), assoluto o `file://`.
- Un'immagine da sola su una riga viene mostrata a tutta pagina nell'anteprima, ridotta alla larghezza della colonna e mai ingrandita.
- Le immagini su internet (`https://…`) **non vengono scaricate** dall'anteprima, per rispetto della privacy: al loro posto compare un avviso. Nell'HTML esportato restano come link e le carica il browser.
- Il testo tra parentesi quadre è la descrizione alternativa: scrivila sempre, serve all'accessibilità.

### Tabelle

```markdown
| Voce    | Q1    | Note     |
|:--------|------:|:--------:|
| Ricavi  | 1.200 | in linea |
| Costi   |   800 | `ok`     |
```

I due punti nella riga di separazione decidono l'allineamento: `:---` a sinistra, `---:` a destra, `:---:` al centro. Per scrivere una barra verticale dentro una cella usa `\|`. Non serve allineare le colonne a mano: ci pensa **Ctrl+Maiusc+T** (vedi sezione 6).

### Note a piè di pagina

```markdown
Il dato è stimato[^fonte].

[^fonte]: Rilevazione interna, settembre 2026.
```

Le note sono numerate nell'ordine in cui compaiono nel testo e raccolte in fondo al documento.

### Codice

````markdown
```python
print("Ciao")
```
````

Sono accettati anche i blocchi con `~~~` e i blocchi rientrati di quattro spazi.

### Linea orizzontale

Una riga con `---`, `***` o `___` (preceduta da una riga vuota).

## 6. Comandi di scrittura

Si trovano nel menu principale e hanno scorciatoie dedicate.

| Comando | Scorciatoia | Comportamento |
|---|---|---|
| Grassetto | Ctrl+B | Avvolge la selezione in `**…**`; se è già in grassetto lo toglie. Senza selezione inserisce `****` con il cursore in mezzo. |
| Corsivo | Ctrl+I | Come sopra con `*…*`. |
| Titolo 1…6 | Ctrl+1 … Ctrl+6 | Trasforma la riga corrente nel titolo del livello scelto. |
| Testo normale | Ctrl+0 | Toglie i `#` dalla riga corrente. |
| Inserisci link | Ctrl+K | Con del testo selezionato crea `[testo](https://)` e seleziona l'indirizzo da sostituire; con un URL selezionato crea `[](URL)` e mette il cursore sul testo. |
| Inserisci immagine | Ctrl+Maiusc+I | Sceglie un file immagine e inserisce `![nome](percorso)`. Se il documento è già salvato il percorso è relativo alla sua cartella, altrimenti è assoluto. |
| Inserisci/allinea tabella | Ctrl+Maiusc+T | Fuori da una tabella ne inserisce una di 3 colonne; con il cursore dentro una tabella ne riallinea tutte le colonne, rispettando l'allineamento scelto e i caratteri larghi (cinese, giapponese, coreano). |

Consiglio: salva il documento prima di inserire immagini, così i percorsi saranno relativi e il documento resterà portabile insieme alla sua cartella.

## 7. Tutte le scorciatoie

| Scorciatoia | Azione |
|---|---|
| Ctrl+N | Nuovo documento |
| Ctrl+O | Apri/Importa Markdown |
| Ctrl+S | Salva |
| Ctrl+Maiusc+S | Salva con nome |
| Ctrl+Maiusc+E | Esporta HTML |
| Ctrl+Maiusc+P | Esporta PDF |
| Ctrl+L | Resa live |
| Ctrl+P | Anteprima |
| F11 | Schermo intero |
| F7 | Controllo ortografico acceso/spento |
| Ctrl+Z / Ctrl+Maiusc+Z | Annulla / Ripeti |
| Ctrl+F | Trova |
| Ctrl+H | Trova e sostituisci |
| Ctrl+B / Ctrl+I | Grassetto / Corsivo |
| Ctrl+K | Link |
| Ctrl+Maiusc+I | Immagine |
| Ctrl+Maiusc+T | Inserisci o allinea tabella |
| Ctrl+1 … Ctrl+6, Ctrl+0 | Livello del titolo / testo normale |
| Ctrl+Q | Esci |

## 8. Trova e sostituisci

**Ctrl+F** apre la barra di ricerca, **Ctrl+H** aggiunge il campo di sostituzione.

- **Invio** o la freccia giù vanno al risultato successivo, la freccia su al precedente; la ricerca riparte dall'inizio quando arriva in fondo.
- **Aa** distingue maiuscole e minuscole.
- **Sostituisci** cambia il risultato corrente e passa al successivo; **Tutti** sostituisce ogni occorrenza in un solo passo, annullabile con Ctrl+Z.
- **Esc** chiude la barra.

## 9. Controllo ortografico

Premi **F7** o il pulsante con il segno di spunta. Le parole sconosciute vengono sottolineate mentre scrivi; con il **tasto destro** su una parola ottieni i suggerimenti e puoi aggiungerla al dizionario personale. La lingua del dizionario si sceglie dal menu a tendina nella barra ortografia ed è indipendente dalla lingua dell'interfaccia: puoi avere i menu in italiano e controllare un testo in inglese britannico (`en_GB`, pacchetto `hunspell-en-gb`).

Per italiano e francese RuscaMark aggiunge al dizionario personale i frammenti di elisione (`dell'`, `quest'`, `qu'`, `jusqu'`…), così non vengono segnalati come errori. La scelta acceso/spento viene ricordata al riavvio.

Il controllo avviene solo con i dizionari installati sul computer: il testo non viene mai inviato in rete.

## 10. Obiettivo di parole

Fai clic su **🎯 Obiettivo** nella barra di stato (o usa il menu) e imposta il numero di parole da raggiungere; 0 lo disattiva. Una barra di avanzamento indica quante parole mancano e cambia colore quando l'obiettivo è raggiunto.

## 11. Esportare in PDF e in HTML

PDF e HTML hanno lo **stesso stile**, quello delle guide di riferimento dei RuscaLinux OS Tools, indipendentemente dal tema chiaro o scuro dell'editor:

- i titoli di livello 1 diventano un **banner** con sfumatura dal rosa al prugna e testo bianco; il paragrafo subito dopo è un'introduzione in corpo più grande;
- i titoli di livello 2 sono prugna con un filetto rosa sotto, quelli di livello 3 e successivi in malva;
- il codice in linea è una «pillola» rosa chiaro; i blocchi di codice sono riquadri prugna scuro con testo chiaro e barra rosa a sinistra;
- le citazioni sono riquadri rosa chiaro con barra malva;
- le tabelle hanno l'intestazione prugna con testo bianco, righe alternate rosate e occupano tutta la larghezza;
- i caratteri sono DejaVu Sans e DejaVu Sans Mono (pacchetto `fonts-dejavu-core`);
- in fondo a ogni pagina c'è il piè di pagina «*titolo* - pag. *N* / *totale*», dove il titolo è il primo titolo di livello 1 (o il nome del file).

Non ci sono riferimenti al programma o al sito.

### PDF

**Ctrl+Maiusc+P** (oppure menu → *Esporta PDF…*) crea direttamente il file PDF, senza passare dalla finestra di stampa.

- Il formato carta è quello predefinito del sistema (A4 in Europa, Letter negli Stati Uniti), con margini di 2 cm; il testo è a 10 punti.
- I paragrafi lunghi continuano sulla pagina successiva; un titolo non resta mai da solo in fondo a una pagina; i blocchi di codice brevi non vengono spezzati, quelli lunghi continuano nella pagina successiva con il loro riquadro.
- Le tabelle vanno a capo dentro la cella e, se continuano sulla pagina successiva, la riga di intestazione viene ripetuta.
- Le immagini locali sono inserite alla loro dimensione naturale, ridotte se più larghe della pagina. Le immagini remote non vengono scaricate: al loro posto compare il testo alternativo.

### HTML

**Ctrl+Maiusc+E** crea una pagina HTML con lo stile descritto sopra, il titolo preso dal primo titolo di livello 1 e la lingua del documento presa dal dizionario ortografico in uso. Sullo schermo il documento appare come un foglio bianco centrato su fondo rosato.

- **Immagini locali**: i percorsi vengono ricalcolati rispetto alla cartella in cui salvi l'HTML, quindi funzionano anche esportando in un'altra cartella.
- **File unico**: attivando in Preferenze «Incorpora le immagini nell'export HTML» le immagini vengono inserite dentro il file (base64). Il file è più pesante ma si può inviare o spostare da solo.
- **Stampa dal browser**: l'HTML contiene uno stile di stampa A4 con margini di 2 cm, colori di sfondo conservati, titoli non separati dal testo che segue, codice, citazioni e immagini non spezzati e lo stesso piè di pagina del PDF (nei browser che supportano i margini di pagina CSS, come Chromium e i derivati).

Il codice HTML scritto dentro il Markdown (ad esempio `<br>` o `<div>`) non viene eseguito ma mostrato come testo: è una scelta di sicurezza.

## 12. Preferenze

Dal menu principale → **Preferenze…**

| Opzione | Effetto |
|---|---|
| Lingua interfaccia | Una delle 15 lingue ufficiali; il cambio è immediato. Con l'arabo tutta l'interfaccia passa da destra a sinistra. |
| Tema scuro (prugna) | Alterna il tema rosa chiaro e il tema prugna scuro. |
| Resa live della formattazione | Come Ctrl+L. |
| Pagina centrata | Se attiva, il testo resta in una colonna centrata; se disattiva occupa tutta la larghezza e una linea guida verticale indica la larghezza di pagina. |
| Larghezza pagina (caratteri) | Da 40 a 140; misurata sul carattere medio del font scelto. 60–75 è la misura più comoda da leggere. |
| Interlinea | *Compatta*, *Normale* (predefinita) o *Ariosa*: lo spazio tra le righe dell'editor e dell'anteprima, in proporzione al corpo del font (1,25 – 1,5 – 1,75 volte). Blocchi di codice e tabelle restano compatti. |
| Incorpora le immagini nell'export HTML | Vedi sezione 11. |
| Font di sistema e Dimensione | Carattere dell'editor, con anteprima. |

I margini laterali si adattano alla finestra: nelle finestre strette restano almeno al 4% della larghezza (da 16 a 48 pixel), in quelle larghe lo spazio libero viene diviso in parti uguali ai due lati.

## 13. Lingue dell'interfaccia

Inglese, cinese semplificato, spagnolo, hindi, arabo, portoghese brasiliano, russo, giapponese, tedesco, francese, italiano, coreano, indonesiano, turco e polacco. Al primo avvio RuscaMark usa la lingua del sistema; poi ricorda quella scelta nelle Preferenze.

Le traduzioni sono file JSON in `/usr/share/ruscamark/lang/`. Per correggere o personalizzare una traduzione copia il file in `~/.config/ruscamark/lang/` e modificalo: la copia personale ha la precedenza. Se una frase manca, viene mostrata in inglese.

## 14. File e cartelle

| Percorso | Contenuto |
|---|---|
| `~/.config/ruscamark/config.json` | Preferenze, dimensioni della finestra, stato dell'ortografia |
| `~/.config/ruscamark/lang/` | Traduzioni personalizzate (facoltative) |
| `~/.config/ruscamark/icons/` | Copia dell'icona del programma |
| `~/.local/share/gtksourceview-5/styles/` | Schemi colore rosa e prugna dell'editor |
| `~/.config/enchant/<lingua>.dic` | Dizionario personale (con i frammenti di elisione) |
| `~/.config/enchant/<lingua>.dic.ruscamark-added` | Elenco dei frammenti aggiunti da RuscaMark, per non toccare le parole aggiunte da te |

Per tornare alle impostazioni iniziali chiudi RuscaMark e cancella `config.json`.

## 15. Privacy e sicurezza

| Principio | Come lo rispetta RuscaMark |
|---|---|
| Dati elaborati | Solo in locale, sul tuo computer |
| Invio a server remoti o su internet | Mai: il programma non apre connessioni di rete |
| Telemetria e statistiche d'uso | Nessuna |
| Raccolta di dati personali | Nessuna |
| Comandi pericolosi o dannosi | Nessuno; non servono permessi di amministratore |
| Operazioni sensibili | Avvengono solo su tua richiesta e sono sempre visibili |

**Tutti i dati elaborati restano in locale.** Nessun testo, documento o file viene inviato a server remoti o su internet.

### Rete

RuscaMark non contiene codice che si collega alla rete. In particolare:

- l'anteprima mostra solo immagini presenti sul computer; quelle con indirizzo `https://…` non vengono scaricate e al loro posto compare un avviso;
- il controllo ortografico usa esclusivamente i dizionari installati (hunspell); il testo non lascia mai il computer;
- la voce di menu «Sito web — ruscalinux.org» apre il tuo browser, e solo quando la scegli.

L'HTML esportato è un file come un altro: se il documento contiene immagini remote, sarà il **browser** che apre l'HTML a scaricarle. Per un file completamente autonomo usa immagini locali e attiva «Incorpora le immagini nell'export HTML».

### Sicurezza dei contenuti

- Il codice HTML scritto dentro il Markdown non viene eseguito, né nell'anteprima né nell'export: viene mostrato come testo.
- I link pericolosi (`javascript:`, `vbscript:`, `data:text/html`) vengono neutralizzati nell'HTML esportato.
- Aprire un file Markdown non esegue nulla: è solo testo.

### File scritti sul computer

RuscaMark scrive soltanto i documenti che salvi o esporti tu, più i file di configurazione elencati nella sezione 14, tutti nella tua cartella personale. Non modifica file di sistema. Nel dizionario personale aggiunge solo i frammenti di elisione italiani e francesi, tenendone un elenco separato per non alterare mai le parole che hai aggiunto tu.

### Integrità del pacchetto

Verifica sempre il pacchetto prima di installarlo:

```bash
sha256sum -c SHA256SUMS
```

### Rimuovere ogni traccia

```bash
sudo apt remove ruscamark
rm -rf ~/.config/ruscamark
rm -f ~/.local/share/gtksourceview-5/styles/ruscamark-*.xml
```

Il dizionario personale in `~/.config/enchant/` è condiviso con altri programmi: se vuoi, cancella a mano le parole che non ti servono.

## 16. Risoluzione dei problemi

| Problema | Soluzione |
|---|---|
| Il programma non si avvia | Verifica Python 3 e GTK 4 (`gir1.2-gtk-4.0`); controlla il pacchetto con `sha256sum -c SHA256SUMS` e reinstallalo. |
| «Controllo ortografico non disponibile» | Installa `gir1.2-spelling-1` e il dizionario della lingua (es. `hunspell-it`). |
| Annulla/Ripeti o la ricerca evidenziata non funzionano | Installa `gir1.2-gtksource-5`. |
| L'export PDF segnala «python3-gi-cairo» | Installa il pacchetto `python3-gi-cairo` (normalmente arriva insieme a RuscaMark). |
| Nel pannello compare un'icona generica | Avvia RuscaMark dal menu delle applicazioni dopo averlo installato dal pacchetto: l'icona dipende dal file `org.ruscalinux.ruscamark.desktop`. Avviando `ruscamark.py` direttamente dalla cartella dei sorgenti, GNOME non trova il lanciatore e mostra l'icona generica. |
| Un'immagine non compare in anteprima | Controlla il percorso: se relativo, parte dalla cartella del documento salvato. Le immagini remote non vengono mostrate per scelta. |
| Le colonne di una tabella sono storte | Metti il cursore nella tabella e premi Ctrl+Maiusc+T. |
| Una riga con `---` sotto diventa un titolo | Lascia una riga vuota prima di `---` per avere una linea orizzontale. |

Assistenza: info@ruscalinux.org

## 17. Licenza e nota di sviluppo

RuscaMark è software libero distribuito con licenza GPL-3.0: <https://www.gnu.org/licenses/gpl-3.0.html>.

Nota di sviluppo: «Sviluppato con il supporto di strumenti AI: progettazione, specifiche, revisione e responsabilità editoriale sono dell'autore».
