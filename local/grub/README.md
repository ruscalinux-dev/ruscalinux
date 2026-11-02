# GRUB: tema RuscaLinux

Tutto quello che serve al menu GRUB, nella ISO (avvio UEFI) e nel sistema
installato:

| File | A cosa serve |
|---|---|
| `ruscalinux/` | Il tema: immagini, font in formato GRUB, `theme.txt` |
| `splash.png` | Nella ISO va in `boot/grub/splash.png`. Non si vede, ma `theme.cfg` di live-build attiva il tema solo se esiste: è lo stesso fondo del tema |
| `preview.png` | Anteprima del menu, da guardare prima del commit (ignorata da git) |

Il menu BIOS della ISO (isolinux) sta in `../isolinux/`. Tutti questi file si
generano insieme, non si modificano a mano:

```sh
sudo apt install python3-pil librsvg2-bin grub-common
python3 branding/generators/ruscalinux-grub-theme.py
```

Il tema è stato provato con GRUB 2.12 in UEFI e BIOS, a 1920×1080 e a
1280×720.

`steps/30-custom.sh` copia il tema nella build e sostituisce `{{VERSION}}`
con la versione di `release.conf`.

- **ISO:** `boot/grub/themes/ruscalinux/`; l'hook
  `9010-ruscalinux-grub-theme.hook.binary` lo attiva in `theme.cfg` e porta la
  risoluzione da 800×600 a 1920×1080 (poi 1280×720, poi automatica).
- **Sistema installato:** `/boot/grub/themes/ruscalinux/`, attivato da
  `/etc/default/grub.d/99-ruscalinux.cfg` (`GRUB_THEME`, `GRUB_GFXMODE`).

L'avvio BIOS della ISO usa isolinux, non GRUB. Lo stesso generatore crea
anche quel menu, nello stesso stile: `local/isolinux/splash.png` (640×480) e
`local/isolinux/stdmenu.cfg` (colori e posizioni). L'hook mette
`stdmenu.cfg` al posto di quello di live-build; lo includono il menu
principale e tutti i sottomenu. isolinux scrive con un font fisso di 8×16
pixel (griglia di 80×30 caratteri): testata e filo sono allineati a quella
griglia. Provato in QEMU (BIOS): menu, modifica con Tab, sottomenu.

Regole imparate provando il tema in GRUB vero:

- solo percentuali intere (`28%`, non `28.5%`): altrimenti GRUB si ferma con
  “unrecognized number”;
- GRUB disegna i bordi della forma della voce selezionata intorno al testo e
  ne sposta il testo: per questo anche le voci normali hanno una forma, uguale
  ma trasparente (`item_*.png`), altrimenti il testo selezionato “salta”;
- la barra del conto alla rovescia non scende sotto circa 28 px di altezza:
  per questo c'è solo il testo.
