# Tema GRUB RuscaLinux

`ruscalinux/` contiene il tema GRUB usato sia nella ISO (avvio UEFI) sia nel
sistema installato. Non si modifica a mano: si rigenera con

```sh
sudo apt install python3-pil librsvg2-bin grub-common
python3 branding/generators/ruscalinux-grub-theme.py
```

Il generatore scrive anche `preview.png` qui accanto (ignorato da git): è
un'anteprima del menu, da guardare prima del commit. Il tema è stato provato
con GRUB 2.12 in UEFI e BIOS, a 1920×1080 e a 1280×720.

`steps/30-custom.sh` copia il tema nella build e sostituisce `{{VERSION}}`
con la versione di `release.conf`.

- **ISO:** `boot/grub/themes/ruscalinux/`; l'hook
  `9010-ruscalinux-grub-theme.hook.binary` lo attiva in `theme.cfg` e porta la
  risoluzione da 800×600 a 1920×1080 (poi 1280×720, poi automatica).
- **Sistema installato:** `/boot/grub/themes/ruscalinux/`, attivato da
  `/etc/default/grub.d/99-ruscalinux.cfg` (`GRUB_THEME`, `GRUB_GFXMODE`).

L'avvio BIOS della ISO usa isolinux, non GRUB: quel menu ha la sua immagine,
`local/isolinux/splash.png`.

Regole imparate provando il tema in GRUB vero:

- solo percentuali intere (`28%`, non `28.5%`): altrimenti GRUB si ferma con
  “unrecognized number”;
- GRUB disegna i bordi della forma della voce selezionata intorno al testo e
  ne sposta il testo: per questo anche le voci normali hanno una forma, uguale
  ma trasparente (`item_*.png`), altrimenti il testo selezionato “salta”;
- la barra del conto alla rovescia non scende sotto circa 28 px di altezza:
  per questo c'è solo il testo.
