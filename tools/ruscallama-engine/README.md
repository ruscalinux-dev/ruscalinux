# ruscallama-engine

Motore di inferenza di RuscaLLama e RuscaTranslator: **llama.cpp**, software esterno con licenza MIT (<https://github.com/ggml-org/llama.cpp>), compilato dal sorgente con il backend Vulkan e senza libcurl.

| File | Cosa contiene |
|---|---|
| `make-deb.sh` | Scarica, verifica, compila e impacchetta llama.cpp |
| `checksums/llama.cpp-v<versione>.tar.gz.sha256` | Impronta dell'archivio sorgente della versione fissata |
| `apparmor/usr.lib.ruscallama-engine.llama-server` | Profilo AppArmor, installato in modalità complain |

## Costruire il pacchetto

Dipendenze, una volta sola:

```bash
sudo apt install build-essential cmake pkg-config dpkg-dev wget \
                 libvulkan-dev glslc spirv-headers
```

Poi `./make-deb.sh` (lo lancia anche `make-debs.sh` della distribuzione). La prima compilazione è lunga; il risultato resta in `~/.cache/ruscalinux/ruscallama-engine/` e le build successive rifanno solo il pacchetto.

`RUSCALLAMA_BACKEND=cpu ./make-deb.sh` compila senza Vulkan, per le prove.

## Aggiornare llama.cpp

1. Scegli una release pubblicata da almeno due settimane.
2. Cambia `LLAMA_CPP_VERSION` in `make-deb.sh`.
3. Aggiungi l'impronta: `sha256sum llama.cpp-v<versione>.tar.gz > checksums/llama.cpp-v<versione>.tar.gz.sha256`.
4. Prova RuscaLLama e RuscaTranslator: le opzioni di `llama-server` cambiano tra le versioni.
