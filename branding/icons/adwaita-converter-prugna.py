#!/usr/bin/env python3
"""
Convertitore icone Adwaita: Blu Debian -> Prugna (palette emblem-ruscalinux-prugna)
Converte ricorsivamente tutte le icone SVG in una cartella
Gestisce gradienti, stop-color, fill e tutti i formati

Palette prugna basata su #7f2457 (H:326°, S:56%, L:32%)
Luminosità scalata proporzionalmente, saturazione contenuta (50-58%)
per garantire leggibilità professionale a tutte le dimensioni.
"""

import os
import re
import shutil
from pathlib import Path

# ─────────────────────────────────────────────────────────────────────────────
# Mappatura Blu Adwaita (Debian) → Prugna RuscaLinux
#
#  Colore base brand : #7f2457  H:326° S:56% L:32%
#  Scala luminosità  : L 32% (scuro) → L 70% (chiaro evidenziato)
#  Saturazione       : 50-58%  (meno saturato del precedente rosa #c83e8b)
#
#  Blu originale  →  Prugna corrispondente  (stesso delta-L relativo)
# ─────────────────────────────────────────────────────────────────────────────
CONVERSIONI_COLORI = {

    # ── Tonalità scure (back-tab cartelle, ombre, sfondi) ──────────────────
    '#1a5fb4': '#7f2457',   # L≈40% → L≈32%  prugna profondo (base brand)
    '#1c71d8': '#872659',   # L≈47% → L≈34%  prugna molto scuro
    '#3584e4': '#912b60',   # L≈54% → L≈37%  prugna scuro
    '#2563eb': '#8a2960',   # L≈52% → L≈36%  prugna scuro variante

    # ── Tonalità medie (corpo principale icone) ─────────────────────────────
    '#438de6': '#9d3169',   # L≈57% → L≈41%  prugna medio-scuro  ← era #b7347d
    '#3b82f6': '#a5356f',   # L≈59% → L≈43%  prugna medio        ← era #bc3581
    '#4a7fb8': '#9a3068',   # L≈50% → L≈40%  prugna medio variante
    '#5e92d0': '#ab3872',   # L≈58% → L≈44%  prugna medio-chiaro

    # ── Tonalità medie-chiare (fronte cartelle, fill primario) ──────────────
    '#62a0ea': '#b33d7a',   # L≈64% → L≈48%  prugna chiaro-medio ← era #c83e8b

    # ── Tonalità chiare (highlight, gradienti luminosi) ──────────────────────
    '#99c1f1': '#c45187',   # L≈76% → L≈56%  prugna chiaro       ← era #d364a2
    '#a4caee': '#c24f88',   # L≈77% → L≈55%  prugna chiaro var.  ← era #d469a5

    # ── Tonalità molto chiare (riflessi, bordi luminosi) ────────────────────
    '#afd4ff': '#cc5e93',   # L≈84% → L≈59%  prugna pastello     ← era #d97ab0
    '#c0d5ea': '#cc5d93',   # L≈82% → L≈59%  prugna pastello var.← era #d978ae
    '#bed1ed': '#ca5c92',   # L≈82% → L≈58%  prugna pastello alt.

    # ── Tonalità chiarissime (sfondi tenue, aloni) ───────────────────────────
    '#d4e4fc': '#d5729e',   # L≈89% → L≈64%  prugna tenue
    '#e8f1fc': '#dd87aa',   # L≈94% → L≈69%  prugna molto tenue
}

# ─────────────────────────────────────────────────────────────────────────────

def aggiungi_varianti(conversioni):
    """Aggiunge tutte le varianti dei colori (maiuscole, minuscole)"""
    nuove = {}
    for blu, prugna in list(conversioni.items()):
        nuove[blu.upper()] = prugna.upper()
        nuove[blu.lower()] = prugna.lower()
    conversioni.update(nuove)
    return conversioni

CONVERSIONI_COLORI = aggiungi_varianti(CONVERSIONI_COLORI)


def converti_svg(contenuto):
    """Converte tutti i colori blu in prugna nel contenuto SVG"""
    contenuto_modificato = contenuto
    for blu, prugna in CONVERSIONI_COLORI.items():
        contenuto_modificato = re.sub(
            re.escape(blu),
            prugna,
            contenuto_modificato,
            flags=re.IGNORECASE
        )
    return contenuto_modificato


def verifica_conversione(contenuto_originale, contenuto_convertito):
    """Verifica se ci sono stati cambiamenti e restituisce statistiche"""
    if contenuto_originale == contenuto_convertito:
        return False, {}
    sostituzioni = {}
    for blu in CONVERSIONI_COLORI.keys():
        count_before = len(re.findall(re.escape(blu), contenuto_originale, re.IGNORECASE))
        if count_before > 0:
            count_after = len(re.findall(re.escape(blu), contenuto_convertito, re.IGNORECASE))
            sostituzioni[blu] = count_before - count_after
    return True, sostituzioni


def processa_cartella(cartella_input, cartella_output, verbose=True):
    """Processa ricorsivamente tutti i file SVG"""
    cartella_input = Path(cartella_input)
    cartella_output = Path(cartella_output)

    if not cartella_input.exists():
        print(f"❌ Errore: La cartella {cartella_input} non esiste!")
        return False

    cartella_output.mkdir(parents=True, exist_ok=True)

    file_processati = 0
    file_modificati = 0
    file_copiati = 0
    totale_sostituzioni = 0

    print("🔄 Processamento file in corso...\n")

    for root, dirs, files in os.walk(cartella_input):
        rel_path = Path(root).relative_to(cartella_input)
        dest_dir = cartella_output / rel_path
        dest_dir.mkdir(parents=True, exist_ok=True)

        for file in files:
            src_file = Path(root) / file
            dst_file = dest_dir / file

            if file.lower().endswith('.svg'):
                try:
                    with open(src_file, 'r', encoding='utf-8') as f:
                        contenuto_originale = f.read()

                    contenuto_convertito = converti_svg(contenuto_originale)

                    with open(dst_file, 'w', encoding='utf-8') as f:
                        f.write(contenuto_convertito)

                    file_processati += 1
                    modificato, sostituzioni = verifica_conversione(
                        contenuto_originale, contenuto_convertito
                    )

                    if modificato:
                        file_modificati += 1
                        num_sostituzioni = sum(sostituzioni.values())
                        totale_sostituzioni += num_sostituzioni
                        if verbose:
                            print(f"✓ {rel_path / file}: {num_sostituzioni} sostituzioni")

                except Exception as e:
                    print(f"✗ Errore con {src_file}: {e}")
            else:
                if file in ['icon-theme.cache', 'index.theme']:
                    continue
                try:
                    shutil.copy2(src_file, dst_file)
                    file_copiati += 1
                except Exception as e:
                    print(f"✗ Errore copiando {src_file}: {e}")

    print(f"\n{'='*70}")
    print(f"✅ CONVERSIONE COMPLETATA!")
    print(f"{'='*70}")
    print(f"   📊 File SVG processati:           {file_processati}")
    print(f"   🎨 File SVG modificati (con blu): {file_modificati}")
    print(f"   🔄 Totale sostituzioni colore:    {totale_sostituzioni}")
    print(f"   📋 Altri file copiati:            {file_copiati}")
    print(f"{'='*70}\n")

    if file_modificati == 0 and file_processati > 0:
        print(f"⚠️  ATTENZIONE: Nessun colore blu trovato!")
        print(f"   I colori cercati sono: {', '.join(list(CONVERSIONI_COLORI.keys())[:5])}...")
        print(f"   Verifica che la cartella contenga icone Adwaita blu.\n")
        return False

    return True


def crea_index_theme(cartella_input, cartella_output, nome_tema="Adwaita-Prugna"):
    """Copia e adatta il file index.theme originale, con fallback dinamico se non esiste"""
    src_index = Path(cartella_input) / "index.theme"
    dst_index = Path(cartella_output) / "index.theme"

    if src_index.exists():
        try:
            with open(src_index, 'r', encoding='utf-8') as f:
                content = f.read()
            content = re.sub(r'^Name=.*$', f'Name={nome_tema}', content, flags=re.MULTILINE)
            content = re.sub(r'^Comment=.*$',
                             f'Comment=Tema Adwaita Prugna (emblem-ruscalinux-prugna)',
                             content, flags=re.MULTILINE)
            with open(dst_index, 'w', encoding='utf-8') as f:
                f.write(content)
            print(f"✅ File index.theme clonato e aggiornato: {dst_index}\n")
            return
        except Exception as e:
            print(f"❌ Errore durante la modifica di index.theme: {e}")

    print(f"⚠️ Attenzione: index.theme originale non trovato in {cartella_input}.")
    print("   Generazione di un index.theme dinamico di fallback in corso...")

    index_content = f"""[Icon Theme]
Name={nome_tema}
Comment=Tema icone Adwaita con colori prugna RuscaLinux
Inherits=Adwaita,hicolor
Example=folder

# Fallback generato automaticamente.
"""

    dirs_found = []
    for root, _, files in os.walk(cartella_output):
        if any(f.endswith('.svg') or f.endswith('.png') for f in files):
            rel_path = Path(root).relative_to(cartella_output)
            dirs_found.append(str(rel_path).replace('\\', '/'))

    if dirs_found:
        dirs_found.sort()
        index_content += f"Directories={','.join(dirs_found)}\n\n"

        for d in dirs_found:
            size = "16"
            type_str = "Fixed"
            match = re.search(r'(\d+)x\d+', d)
            if match:
                size = match.group(1)
            elif 'scalable' in d or 'symbolic' in d:
                size = "16"
                type_str = "Scalable"

            index_content += f"[{d}]\nSize={size}\nType={type_str}\n"
            if type_str == "Scalable":
                index_content += "MinSize=8\nMaxSize=512\n"

            context = "Applications"
            if   "actions"   in d: context = "Actions"
            elif "places"    in d: context = "Places"
            elif "devices"   in d: context = "Devices"
            elif "emblems"   in d: context = "Emblems"
            elif "mimetypes" in d: context = "MimeTypes"
            elif "status"    in d: context = "Status"
            elif "categories"in d: context = "Categories"

            index_content += f"Context={context}\n\n"

    try:
        with open(dst_index, 'w', encoding='utf-8') as f:
            f.write(index_content)
        print(f"✅ File index.theme dinamico generato con successo in: {dst_index}\n")
    except Exception as e:
        print(f"❌ Errore durante la generazione dell'index.theme: {e}\n")


if __name__ == "__main__":
    import sys

    print("\n" + "="*70)
    print("🍇 Convertitore Icone Adwaita: Blu Debian → Prugna RuscaLinux")
    print("   Palette centrata su #7f2457  (H:326° S:56% L:32%)")
    print("="*70 + "\n")

    if len(sys.argv) < 2:
        print("Uso: python3 script.py <cartella_input> [cartella_output] [nome_tema]\n")
        print("Esempi:")
        print("  python3 script.py /usr/share/icons/Adwaita ./Adwaita-Prugna")
        print("  python3 script.py ./icone-blu ./icone-prugna 'Mio Tema'\n")
        sys.exit(1)

    cartella_input = sys.argv[1]
    cartella_output = sys.argv[2] if len(sys.argv) > 2 else "./Adwaita-Prugna"
    nome_tema      = sys.argv[3] if len(sys.argv) > 3 else "Adwaita-Prugna"

    print(f"📂 Cartella input:  {cartella_input}")
    print(f"📂 Cartella output: {cartella_output}")
    print(f"🏷️  Nome tema:      {nome_tema}\n")

    successo = processa_cartella(cartella_input, cartella_output, verbose=False)

    if successo:
        crea_index_theme(cartella_input, cartella_output, nome_tema)
        print("="*70)
        print("🎉 SUCCESSO! Il tema è pronto")
        print("="*70)
        print("\n📌 Installazione:")
        print(f"   rm -rf ~/.local/share/icons/{Path(cartella_output).name}")
        print(f"   cp -r {cartella_output} ~/.local/share/icons/")
        print(f"   gtk-update-icon-cache -f ~/.local/share/icons/{Path(cartella_output).name}")
        print(f"\n📌 Poi seleziona '{nome_tema}' nelle impostazioni grafiche\n")
    else:
        print("❌ Conversione fallita. Controlla i messaggi sopra.\n")
