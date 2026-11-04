# ruscallama-engine

Motore di inferenza di RuscaLLama e RuscaTranslator: **llama.cpp**, software esterno con licenza MIT (<https://github.com/ggml-org/llama.cpp>), compilato dal sorgente con il backend Vulkan, senza HTTPS e senza interfaccia web.

| File | Cosa contiene |
|---|---|
| `make-deb.sh` | Scarica, verifica, compila e impacchetta l’ultima release stabile di llama.cpp |
| `ultima-versione.sh` | Dice qual è l’ultima release stabile (o quella fissata a mano) |
| `checksums/llama.cpp-v<versione>.tar.gz.sha256` | Impronta dell’archivio sorgente di ogni versione già costruita |
| `apparmor/usr.lib.ruscallama-engine.llama-server` | Profilo AppArmor, installato in modalità complain |

## Costruire il pacchetto

Dipendenze, una volta sola:

```bash
sudo apt install build-essential cmake pkg-config dpkg-dev wget git \
                 libvulkan-dev glslc spirv-headers
```

Poi `./make-deb.sh` (lo lancia anche `make-debs.sh` della distribuzione). La prima compilazione di ogni versione è lunga; il risultato resta in `~/.cache/ruscalinux/ruscallama-engine/` e le build successive rifanno solo il pacchetto.

`RUSCALLAMA_BACKEND=cpu ./make-deb.sh` compila senza Vulkan, per le prove.

## Quale versione di llama.cpp

`make-deb.sh` costruisce sempre l’**ultima release stabile**: quella che GitHub indica come “Latest”, con un tag `vX.Y.Z` (i tag `bNNNN` sono build automatiche e non contano). `ultima-versione.sh` la cerca con l’API di GitHub, poi con il rinvio di `releases/latest`, poi con `git ls-remote`, perché l’API senza autenticazione ammette solo 60 richieste l’ora per indirizzo (con `GITHUB_TOKEN` nell’ambiente il limite sale).

`build.sh` fa lo stesso controllo: se è uscita una release più nuova di quella impacchettata, ricostruisce i pacchetti anche se in `tools/` non è cambiato nulla.

Per costruire una versione precisa (ad esempio quella precedente, se l’ultima dà problemi):

```bash
RUSCALLAMA_LLAMA_VERSION=0.7.0 ./make-deb.sh
```

Senza rete si usa la versione più recente già scaricata e registrata, con un avviso.

## Controlli automatici

1. **Commit.** Il commit scritto nell’archivio deve essere quello a cui punta il tag su GitHub.
2. **Impronta.** La prima volta che una versione viene costruita, la sua impronta SHA-256 viene scritta in `checksums/`; le build successive della stessa versione devono trovare lo stesso archivio. Il file nuovo va aggiunto al repository (`git add`): `make-debs.sh` lo ricorda.
3. **Età.** Una release uscita da meno di 14 giorni viene costruita lo stesso, con un avviso: prova RuscaLLama e RuscaTranslator prima di pubblicare la ISO.
4. **Librerie incluse.** Se llama.cpp aggiunge una cartella in `vendor/` la build si ferma: va dichiarata nel file `copyright` (in `make-deb.sh`), nelle specifiche e in `VENDOR_DICHIARATI`.
5. **Niente rete.** La compilazione gira senza rete (`unshare -rn`), e i binari non devono essere collegati a OpenSSL, libcrypto o curl.
6. **Opzioni.** `llama-server --help` deve elencare tutte le opzioni usate dai due programmi (`OPZIONI_USATE` in `make-deb.sh`): se un’opzione sparisce, la build si ferma invece di produrre un motore che non parte. Quando i programmi cominciano a usare un’opzione nuova, va aggiunta all’elenco.

## Download e privacy

Da quando llama.cpp ha abbandonato libcurl, `LLAMA_CURL=OFF` non ha più effetto: i download passano da cpp-httplib con OpenSSL, attivo di default se sulla macchina di build c’è `libssl-dev`. Per questo `make-deb.sh` usa:

| Opzione | Effetto |
|---|---|
| `LLAMA_OPENSSL=OFF` | Niente HTTPS: il motore non può scaricare modelli da Hugging Face né da altri siti HTTPS |
| `LLAMA_BUILD_UI=OFF`, `LLAMA_USE_PREBUILT_UI=OFF` | La compilazione non scarica l’interfaccia web (i programmi avviano il motore con `--no-webui`) |
| `LLAMA_CONNECT=OFF` | Niente strumento che scarica binari |

Resta tecnicamente possibile un download in `http://` semplice, passato a mano da terminale: toglierlo richiederebbe di modificare il codice di llama.cpp. RuscaLLama e RuscaTranslator non usano mai le opzioni di download.
