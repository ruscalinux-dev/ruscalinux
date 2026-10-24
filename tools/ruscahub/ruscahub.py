#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
RuscaHub — Gestore di AppImage per RuscaLinux
Suite: RuscaTools | Sito: https://www.ruscalinux.org/
Autore: Nunzio Curcuruto (ruscalinux-dev) — © 2026 — GPL-3.0

Funzioni:
  * Apertura/importazione di AppImage (pulsante o drag & drop sulla finestra)
  * Copia automatica in ~/.ruscahub/apps/ (cartella nascosta nella Home)
  * Installazione (voce nel menu GNOME via file .desktop) e disinstallazione
  * Eliminazione: rimuove voce, file .desktop, icona e il file AppImage
  * Estrazione icone robusta: legge la chiave Icon= del .desktop interno,
    segue i collegamenti simbolici (.DirIcon), cerca in usr/share/icons e
    usr/share/pixmaps; usa unsquashfs (senza eseguire l'AppImage) e ripiega
    sul runtime --appimage-extract. Riparazione automatica delle voci già
    importate senza icona.
  * Pannello "Informazioni" nello stile RuscaTools (rosa → prugna)
  * Internazionalizzazione: 15 lingue in lang/*.json, fallback en.json
    (override con variabile d'ambiente RUSCAHUB_LANG)
"""

import gi
gi.require_version("Gtk", "4.0")
from gi.repository import Gtk, Gdk, Gio, GLib, Pango

import cairo
import math
import os
import io
import json
import gzip
import shutil
import struct
import subprocess
import threading
import uuid
import configparser
import tempfile
import re
from pathlib import Path

# ------------------------------------------------------------------ costanti
APP_ID      = "org.ruscalinux.RuscaHub"
APP_NAME    = "RuscaHub"
APP_VERSION = "1.99.2"
AUTHOR      = "Nunzio Curcuruto"
SITE_URI    = "https://www.ruscalinux.org/"
SITE_LABEL  = "ruscalinux.org"

BASE_DIR    = Path.home() / ".ruscahub"
APPS_DIR    = BASE_DIR / "apps"
ICONS_DIR   = BASE_DIR / "icons"
DB_FILE     = BASE_DIR / "ruscahub.json"
DESKTOP_DIR = Path(GLib.get_user_data_dir()) / "applications"   # ~/.local/share/applications

ICON_SCAN_VERSION = 2       # incrementare quando cambia la logica di estrazione icone

# ------------------------------------------------------------------ i18n
SCRIPT_DIR = Path(__file__).resolve().parent
LANG_DIRS  = (SCRIPT_DIR / "lang", Path("/usr/share/ruscahub/lang"))

SUPPORTED_LANGS = ("en", "zh_CN", "es", "hi", "ar", "pt_BR", "ru", "ja",
                   "de", "fr", "it", "ko", "id", "tr", "pl")
LANG_ALIASES = {"zh": "zh_CN", "pt": "pt_BR"}
RTL_LANGS = ("ar",)

# Copia interna di en.json: ultima rete di sicurezza se la cartella lang/ manca.
BUILTIN_EN = {
    "app_description": ("AppImage manager with drag & drop import, storage in a hidden "
                        "folder of the Home, installation and uninstallation from the "
                        "GNOME menu, pink⇒plum themes."),
    "ai_note": ("Developed with the support of AI tools: design, specifications, "
                "review and editorial responsibility belong to the author."),
    "license": "© 2026 — GPL-3.0 License",
    "add_appimage": "Add AppImage",
    "about_title": "About %s",
    "close": "Close",
    "author": "Author: %s",
    "empty_title": "No AppImage archived",
    "empty_hint": "Drag an .AppImage file here or press “Add AppImage”.",
    "state_installed": "Installed",
    "state_archived": "Archived",
    "run_tooltip": "Run the AppImage",
    "install": "Install",
    "uninstall": "Uninstall",
    "install_tooltip": "Create or remove the entry in the GNOME menu",
    "remove_tooltip": "Remove: deletes entry, icon and AppImage file",
    "chooser_title": "Select one or more AppImage files",
    "open": "Open",
    "cancel": "Cancel",
    "desktop_comment_default": "AppImage managed by RuscaHub",
}


def _match_lang(raw):
    """Converte un nome di locale (it_IT.UTF-8, pt-BR, zh_TW…) in una lingua supportata."""
    n = raw.split(".")[0].split("@")[0].replace("-", "_").strip()
    if n in SUPPORTED_LANGS:
        return n
    base = n.split("_")[0]
    if base in LANG_ALIASES:
        return LANG_ALIASES[base]
    if base in SUPPORTED_LANGS:
        return base
    return None


def _detect_lang():
    env = os.environ.get("RUSCAHUB_LANG", "").strip()
    if env:
        found = _match_lang(env)
        if found:
            return found
    try:
        names = GLib.get_language_names()
    except Exception:
        names = []
    for raw in names:
        found = _match_lang(raw)
        if found:
            return found
    return "en"


def _load_lang_file(code):
    for d in LANG_DIRS:
        f = d / f"{code}.json"
        if f.is_file():
            try:
                data = json.loads(f.read_text(encoding="utf-8"))
                if isinstance(data, dict):
                    return {str(k): str(v) for k, v in data.items()}
            except (OSError, ValueError):
                pass
    return {}


LANG = _detect_lang()
TR_EN = _load_lang_file("en")
TR = TR_EN if LANG == "en" else _load_lang_file(LANG)


def _(key):
    """Traduzione: lingua attiva → en.json → copia interna → chiave grezza (mai crash)."""
    return TR.get(key) or TR_EN.get(key) or BUILTIN_EN.get(key) or key


def _f(key, value):
    """Traduzione con un segnaposto %s; tollera traduzioni senza segnaposto."""
    return _(key).replace("%s", str(value), 1)

# ------------------------------------------------------------------ tema CSS
CSS = """
window.ruscahub-win, window.about-win { background-color: #f9eef4; }

headerbar {
    background-color: #f2c7db;
    border-bottom: 1px solid #e2a9c8;
}
headerbar label, headerbar .title { color: #4a1d43; font-weight: bold; }
headerbar button { color: #4a1d43; background: none; border: none; box-shadow: none; }

button.plum {
    background-image: linear-gradient(to bottom, #c86aa6, #7c2f63);
    color: #ffffff; font-weight: bold;
    border-radius: 9px; border: none;
    padding: 6px 14px;
}
button.plum:hover { background-image: linear-gradient(to bottom, #d47cb2, #8a3a70); }

button.flat-plum { background: none; border: none; box-shadow: none;
                   color: #7c2f63; font-weight: bold; padding: 6px 18px; }
button.flat-plum:hover { background-color: #f0d8e6; border-radius: 8px; }

button.trash { background: none; border: none; box-shadow: none; color: #8a2f4d; }
button.trash:hover { background-color: #f3d3de; border-radius: 8px; }

button.run { background: none; border: none; box-shadow: none; color: #7c2f63; }
button.run:hover { background-color: #f0d8e6; border-radius: 8px; }

list.apps { background: none; }
row { background: none; }
row.approw {
    background-color: #fdf4f9;
    border: 1px solid #eccfe0;
    border-radius: 12px;
    margin: 4px 8px;
}
row.approw:hover { background-color: #fbeaf3; }

label.app-name  { color: #4a1d43; font-weight: bold; font-size: 15px; }
label.app-sub   { color: #8a5f7d; font-size: 12px; }
label.chip-yes  { background-color: #d98cb3; color: #3d1230;
                  border-radius: 8px; padding: 2px 10px; font-weight: bold; font-size: 12px; }
label.chip-no   { background-color: #efd7e5; color: #7c4a68;
                  border-radius: 8px; padding: 2px 10px; font-size: 12px; }
label.hint      { color: #8a5f7d; font-size: 14px; }

label.about-name { color: #4a1d43; font-size: 24px; font-weight: 800; }
label.about-ver  { color: #7c4a68; font-size: 15px; }
label.about-body { color: #5a2b50; font-size: 15px; }
label.about-dim  { color: #7c4a68; font-size: 13px; }
linkbutton label { color: #7c2f63; }
"""

# ------------------------------------------------------------------ icone
def _round_rect(ctx, x, y, w, h, r):
    ctx.new_sub_path()
    ctx.arc(x + w - r, y + r, r, math.radians(-90), math.radians(0))
    ctx.arc(x + w - r, y + h - r, r, math.radians(0), math.radians(90))
    ctx.arc(x + r, y + h - r, r, math.radians(90), math.radians(180))
    ctx.arc(x + r, y + r, r, math.radians(180), math.radians(270))
    ctx.close_path()


def render_hub_icon(size=96):
    """Icona RuscaHub: quadrato arrotondato con gradiente rosa → prugna e glifo 'hub'."""
    surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, size, size)
    ctx = cairo.Context(surf)
    _round_rect(ctx, 0, 0, size, size, size * 0.22)
    g = cairo.LinearGradient(0, 0, size, size)
    g.add_color_stop_rgb(0.00, 0.83, 0.42, 0.66)   # rosa
    g.add_color_stop_rgb(0.55, 0.62, 0.22, 0.47)   # magenta
    g.add_color_stop_rgb(1.00, 0.33, 0.10, 0.30)   # prugna scuro
    ctx.set_source(g)
    ctx.fill()

    c = size / 2.0
    ctx.set_source_rgba(1, 1, 1, 0.95)
    ctx.set_line_width(size * 0.07)
    ctx.set_line_cap(cairo.LINE_CAP_ROUND)
    for ang in (45, 135, 225, 315):                # raggi del mozzo (hub)
        a = math.radians(ang)
        ctx.move_to(c + math.cos(a) * size * 0.15, c + math.sin(a) * size * 0.15)
        ctx.line_to(c + math.cos(a) * size * 0.29, c + math.sin(a) * size * 0.29)
        ctx.stroke()
        ctx.arc(c + math.cos(a) * size * 0.345, c + math.sin(a) * size * 0.345,
                size * 0.055, 0, 2 * math.pi)
        ctx.fill()
    ctx.arc(c, c, size * 0.11, 0, 2 * math.pi)     # mozzo centrale
    ctx.fill()
    surf.flush()
    return surf


def texture_from_surface(surf):
    buf = io.BytesIO()
    surf.write_to_png(buf)
    return Gdk.Texture.new_from_bytes(GLib.Bytes.new(buf.getvalue()))


def _icon_model(texture):
    """Modello GListModel contenente una texture (firma ufficiale GTK 4)."""
    model = Gio.ListStore.new(Gdk.Texture)
    model.append(texture)
    return model


def set_win_icon(win, size=64):
    """Imposta l'icona della finestra in modo compatibile con GTK 4."""
    tex = texture_from_surface(render_hub_icon(size))
    for attempt in (
        lambda: win.set_icon_list([tex]),               # alcune build accettano la lista
        lambda: win.set_icon_list(_icon_model(tex)),    # firma ufficiale: GListModel
    ):
        try:
            attempt()
            return
        except Exception:
            continue
    try:
        win.set_icon_name(APP_ID)                       # ultima ratio: icona di tema
    except Exception:
        pass


def icon_picture(surface, size):
    """Icona a dimensione fissa: DrawingArea + superficie cairo disegnata esatta.

    La draw-func di Gtk.DrawingArea riceve un cairo.Context: la superficie
    viene scalata e centrata nel rettangolo richiesto. Il widget non si
    espande mai (size-request + allineamenti CENTER + expand disattivati).
    """
    area = Gtk.DrawingArea()
    area.set_size_request(size, size)
    area.set_hexpand(False)
    area.set_vexpand(False)
    area.set_halign(Gtk.Align.CENTER)
    area.set_valign(Gtk.Align.CENTER)

    def _draw(widget, cr, width, height):
        sw = surface.get_width()
        sh = surface.get_height()
        if sw <= 0 or sh <= 0:
            return
        scale = min(width / sw, height / sh)
        cr.scale(scale, scale)
        ox = (width / scale - sw) / 2.0
        oy = (height / scale - sh) / 2.0
        cr.set_source_surface(surface, ox, oy)
        cr.get_source().set_filter(cairo.FILTER_BEST)   # scalatura pulita
        cr.paint()

    area.set_draw_func(_draw)
    return area


def app_icon_widget(path, size=48):
    """Icona di un'AppImage (PNG o SVG) a dimensione fissa; ripiega sull'icona hub."""
    if path and Path(path).is_file():
        try:
            tex = Gdk.Texture.new_from_filename(str(path))
            img = Gtk.Image.new_from_paintable(tex)
            img.set_pixel_size(size)
            img.set_size_request(size, size)
            img.set_halign(Gtk.Align.CENTER)
            img.set_valign(Gtk.Align.CENTER)
            return img
        except Exception:
            pass
    return icon_picture(render_hub_icon(96), size)

# ------------------------------------------------------------------ meta AppImage
PNG_MAGIC = b"\x89PNG\r\n\x1a\n"
ICON_EXTS = (".png", ".svg", ".svgz", ".xpm")


def _squashfs_offset(path):
    """Offset del filesystem squashfs dentro un'AppImage di tipo 2 (fine dell'ELF)."""
    try:
        with open(path, "rb") as f:
            h = f.read(64)
            if len(h) < 52 or h[:4] != b"\x7fELF":
                return None
            end = "<" if h[5] == 1 else ">"
            if h[4] == 2:                                   # ELF64
                shoff = struct.unpack_from(end + "Q", h, 0x28)[0]
                shentsize, shnum = struct.unpack_from(end + "HH", h, 0x3A)
            elif h[4] == 1:                                 # ELF32
                shoff = struct.unpack_from(end + "I", h, 0x20)[0]
                shentsize, shnum = struct.unpack_from(end + "HH", h, 0x2E)
            else:
                return None
            off = shoff + shentsize * shnum
            f.seek(off)
            return off if f.read(4) == b"hsqs" else None
    except (OSError, struct.error):
        return None


class _Extractor:
    """Estrae singoli percorsi dall'AppImage in <tmp>/squashfs-root.

    method = "unsquashfs": legge il filesystem senza eseguire l'AppImage;
    method = "runtime"   : usa --appimage-extract del runtime dell'AppImage.
    """

    def __init__(self, app_path, tmp, method, offset=None):
        self.app = Path(app_path).resolve()
        self.tmp = Path(tmp)
        self.root = self.tmp / "squashfs-root"
        self.method = method
        self.offset = offset

    def extract(self, pattern):
        if self.method == "unsquashfs":
            cmd = ["unsquashfs", "-no-progress", "-no-xattrs", "-f",
                   "-o", str(self.offset), "-d", str(self.root),
                   str(self.app), pattern]
        else:
            cmd = [str(self.app), "--appimage-extract", pattern]
        try:
            subprocess.run(cmd, cwd=str(self.tmp), stdin=subprocess.DEVNULL,
                           capture_output=True, timeout=120)
        except (OSError, subprocess.SubprocessError):
            pass

    def resolve(self, rel):
        """File reale per `rel`; se è un symlink estrae e segue il bersaglio."""
        p = self.root / rel
        for _i in range(10):
            if p.is_symlink():
                target = os.readlink(p)
                if os.path.isabs(target):
                    nxt = self.root / target.lstrip("/")
                else:
                    nxt = p.parent / target
                nxt = Path(os.path.normpath(str(nxt)))
                try:
                    rel_next = nxt.relative_to(self.root)
                except ValueError:                          # fuori dall'AppImage
                    return None
                if not (nxt.exists() or nxt.is_symlink()):
                    self.extract(str(rel_next))
                p = nxt
                continue
            return p if p.is_file() else None
        return None


def _probe_icon(path):
    """(tipo, punteggio): SVG preferito, poi il PNG più grande."""
    try:
        with open(path, "rb") as f:
            head = f.read(4096)
    except OSError:
        return None, 0
    if head.startswith(PNG_MAGIC) and len(head) >= 24:
        return "png", struct.unpack(">I", head[16:20])[0]
    if head[:2] == b"\x1f\x8b":
        return "svgz", 100000
    if b"<svg" in head.lower():
        return "svg", 100000
    return None, 0


def _store_icon(src, kind, entry_id):
    for ext in (".png", ".svg"):                            # vecchie icone della voce
        (ICONS_DIR / f"{entry_id}{ext}").unlink(missing_ok=True)
    if kind == "png":
        dest = ICONS_DIR / f"{entry_id}.png"
        shutil.copyfile(src, dest)
        return dest
    data = Path(src).read_bytes()
    if kind == "svgz":
        data = gzip.decompress(data)
        if b"<svg" not in data[:4096].lower():
            return None
    dest = ICONS_DIR / f"{entry_id}.svg"
    dest.write_bytes(data)
    return dest


def _extract_with(ex, entry_id):
    """Un tentativo di estrazione con un metodo. None se non si è trovato nulla."""
    shutil.rmtree(ex.root, ignore_errors=True)
    found = {"name": "", "comment": "", "wmclass": "", "icon": None}

    # 1) .desktop interno (spesso è un symlink a usr/share/applications/…)
    icon_key = ""
    ex.extract("*.desktop")
    desk = None
    if ex.root.is_dir():
        for cand in sorted(ex.root.glob("*.desktop")):
            desk = ex.resolve(cand.name)
            if desk:
                break
    if desk:
        cp = configparser.ConfigParser(strict=False, interpolation=None)
        try:
            cp.read_string(desk.read_text(encoding="utf-8", errors="ignore"))
            if cp.has_section("Desktop Entry"):
                g = lambda k: cp.get("Desktop Entry", k, fallback="").strip()
                found["name"] = g("Name")
                found["comment"] = g("Comment")
                found["wmclass"] = g("StartupWMClass")
                icon_key = g("Icon")
        except configparser.Error:
            pass

    # 2) candidati icona: .DirIcon (seguendo i symlink) + nome dalla chiave Icon=
    cands = []
    ex.extract(".DirIcon")
    p = ex.resolve(".DirIcon")
    if p:
        cands.append(p)

    stem = Path(icon_key).name if icon_key else ""
    for ext in ICON_EXTS:
        if stem.lower().endswith(ext):
            stem = stem[: -len(ext)]
            break
    if stem and not any(ch in stem for ch in "*?[]\\"):
        patterns = (f"{stem}.*",
                    f"usr/share/icons/*/*/*/{stem}.*",
                    f"usr/share/pixmaps/{stem}.*")
        for pat in patterns:
            ex.extract(pat)
        if ex.root.is_dir():
            for pat in patterns:
                for c in sorted(ex.root.glob(pat)):
                    real = ex.resolve(str(c.relative_to(ex.root)))
                    if real and real not in cands:
                        cands.append(real)

    best, best_kind, best_score = None, None, -1
    for c in cands:
        kind, score = _probe_icon(c)
        if kind and score > best_score:
            best, best_kind, best_score = c, kind, score
    if best is not None:
        try:
            dest = _store_icon(best, best_kind, entry_id)
            found["icon"] = str(dest) if dest else None
        except (OSError, EOFError, ValueError):
            pass

    if not desk and not found["icon"]:
        return None
    return found


def extract_meta(app_path: Path, entry_id: str):
    """Estrae nome, commento, StartupWMClass e icona dall'AppImage."""
    default_name = re.sub(r"(?i)\.appimage$", "", Path(app_path).name)
    meta = {"name": default_name, "comment": "", "icon": None,
            "wmclass": "", "from_desktop": False}
    ICONS_DIR.mkdir(parents=True, exist_ok=True)
    tmp = Path(tempfile.mkdtemp(prefix="ruscahub-"))
    try:
        methods = []
        off = _squashfs_offset(app_path)
        if off is not None and shutil.which("unsquashfs"):
            methods.append(_Extractor(app_path, tmp, "unsquashfs", off))
        methods.append(_Extractor(app_path, tmp, "runtime"))
        for ex in methods:
            found = _extract_with(ex, entry_id)
            if not found:
                continue
            if found["name"] and not meta["from_desktop"]:
                meta["name"] = found["name"]
                meta["from_desktop"] = True
            meta["comment"] = meta["comment"] or found["comment"]
            meta["wmclass"] = meta["wmclass"] or found["wmclass"]
            if found["icon"]:
                meta["icon"] = found["icon"]
                break
    except Exception:
        pass
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    return meta

# ------------------------------------------------------------------ finestra Informazioni
class AboutWindow(Gtk.Window):
    """Ricalca lo stile del pannello Informazioni di RuscaMark (modello RuscaTools)."""

    def __init__(self, parent):
        super().__init__(transient_for=parent, modal=True)
        self.add_css_class("about-win")
        self.set_title("")
        self.set_default_size(500, 680)
        set_win_icon(self)

        hb = Gtk.HeaderBar()
        hb.set_show_title_buttons(False)
        hb.set_title_widget(Gtk.Label(label=_f("about_title", APP_NAME)))
        btn_x = Gtk.Button.new_from_icon_name("window-close-symbolic")
        btn_x.set_tooltip_text(_("close"))
        btn_x.connect("clicked", lambda *_: self.close())
        hb.pack_end(btn_x)
        self.set_titlebar(hb)

        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        box.set_margin_top(28); box.set_margin_bottom(20)
        box.set_margin_start(32); box.set_margin_end(32)

        icon = icon_picture(render_hub_icon(128), 128)
        box.append(icon)

        def label(text, css=None, wrap=False):
            lb = Gtk.Label(label=text)
            lb.set_halign(Gtk.Align.CENTER)
            lb.set_justify(Gtk.Justification.CENTER)
            if css:
                lb.add_css_class(css)
            if wrap:
                lb.set_wrap(True)
                lb.set_max_width_chars(52)
            box.append(lb)
            return lb

        label(APP_NAME, "about-name")
        label(APP_VERSION, "about-ver")
        label(_("app_description"), "about-body", wrap=True)
        label(_f("author", AUTHOR), "about-body")
        label(_("license"), "about-body")
        label(_("ai_note"), "about-dim", wrap=True)

        link = Gtk.LinkButton.new_with_label(SITE_URI, SITE_LABEL)
        link.set_halign(Gtk.Align.CENTER)
        box.append(link)

        box.append(Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL))
        btn = Gtk.Button(label=_("close"))
        btn.add_css_class("flat-plum")
        btn.set_halign(Gtk.Align.CENTER)
        btn.connect("clicked", lambda *_: self.close())
        box.append(btn)

        sw = Gtk.ScrolledWindow()
        sw.set_child(box)
        sw.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        self.set_child(sw)

# ------------------------------------------------------------------ finestra principale
class RuscaHubWindow(Gtk.ApplicationWindow):

    def __init__(self, app):
        super().__init__(application=app)
        self.app = app
        self.add_css_class("ruscahub-win")
        self.set_title(APP_NAME)
        self.set_default_size(780, 560)
        set_win_icon(self)
        self.entries = {}          # id -> dict
        self._pending = 0

        for d in (BASE_DIR, APPS_DIR, ICONS_DIR, DESKTOP_DIR):
            d.mkdir(parents=True, exist_ok=True)

        # ---------- headerbar
        hb = Gtk.HeaderBar()
        btn_add = Gtk.Button(label=_("add_appimage"))
        btn_add.add_css_class("plum")
        btn_add.connect("clicked", lambda *_: self.open_chooser())
        hb.pack_start(btn_add)

        self.spinner = Gtk.Spinner()
        hb.pack_end(self.spinner)
        btn_info = Gtk.Button.new_from_icon_name("dialog-information-symbolic")
        btn_info.set_tooltip_text(_f("about_title", APP_NAME))
        btn_info.connect("clicked", lambda *_: AboutWindow(self).present())
        hb.pack_end(btn_info)
        self.set_titlebar(hb)

        # ---------- corpo
        self.stack = Gtk.Stack()
        self.stack.set_transition_type(Gtk.StackTransitionType.CROSSFADE)

        empty = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=14)
        empty.set_valign(Gtk.Align.CENTER)
        ic = icon_picture(render_hub_icon(128), 128)
        empty.append(ic)
        t = Gtk.Label(label=_("empty_title"))
        t.add_css_class("app-name"); t.set_halign(Gtk.Align.CENTER)
        empty.append(t)
        h = Gtk.Label(label=_("empty_hint"))
        h.set_wrap(True); h.set_justify(Gtk.Justification.CENTER)
        h.add_css_class("hint"); h.set_halign(Gtk.Align.CENTER)
        empty.append(h)
        self.stack.add_named(empty, "empty")

        self.listbox = Gtk.ListBox()
        self.listbox.add_css_class("apps")
        self.listbox.set_selection_mode(Gtk.SelectionMode.NONE)
        sw = Gtk.ScrolledWindow()
        sw.set_child(self.listbox)
        sw.set_margin_top(6); sw.set_margin_bottom(6)
        self.stack.add_named(sw, "list")

        self.set_child(self.stack)

        # ---------- drag & drop
        drop = Gtk.DropTarget.new(Gio.File, Gdk.DragAction.COPY)
        drop.connect("drop", self._on_drop)
        self.add_controller(drop)

        self.load_db()
        self.refresh()
        self._repair_icons()

    # -------------------------------------------------- persistenza
    def load_db(self):
        if DB_FILE.is_file():
            try:
                data = json.loads(DB_FILE.read_text(encoding="utf-8"))
                for e in data:
                    if Path(e["path"]).is_file():
                        self.entries[e["id"]] = e
                    else:  # file sparito: pulizia silenziosa
                        self._remove_desktop(e)
            except Exception:
                self.entries = {}

    def save_db(self):
        DB_FILE.write_text(json.dumps(list(self.entries.values()), indent=2,
                                      ensure_ascii=False), encoding="utf-8")

    # -------------------------------------------------- importazione
    def open_chooser(self):
        filt = Gtk.FileFilter()
        filt.set_name("AppImage")
        filt.add_pattern("*.AppImage")
        filt.add_pattern("*.appimage")
        try:  # GTK >= 4.10
            dlg = Gtk.FileDialog()
            dlg.set_title(_("chooser_title"))
            store = Gio.ListStore.new(Gtk.FileFilter)
            store.append(filt)
            dlg.set_filters(store)
            dlg.open_multiple(self, None, self._on_files_chosen, None)
        except AttributeError:  # GTK 4.8 (Debian Stable)
            native = Gtk.FileChooserNative.new(
                _("chooser_title"), self,
                Gtk.FileChooserAction.OPEN, _("open"), _("cancel"))
            native.set_select_multiple(True)
            native.add_filter(filt)
            native.connect("response", self._on_native_response)
            native.show()

    def _on_files_chosen(self, dlg, res, _ud=None):
        try:
            model = dlg.open_multiple_finish(res)
            files = [model.get_item(i) for i in range(model.get_n_items())]
            self.import_files(files)
        except GLib.Error:
            pass

    def _on_native_response(self, native, resp):
        if resp == Gtk.ResponseType.ACCEPT:
            model = native.get_files()
            files = [model.get_item(i) for i in range(model.get_n_items())]
            self.import_files(files)
        native.destroy()

    def _on_drop(self, _t, value, _x, _y):
        if isinstance(value, Gdk.FileList):
            files = value.get_files()
        elif isinstance(value, Gio.File):
            files = [value]
        else:
            return False
        self.import_files(files)
        return True

    def import_files(self, gfiles):
        for gf in gfiles:
            p = gf.get_path()
            if p and Path(p).is_file() and p.lower().endswith(".appimage"):
                self._pending += 1
                self.spinner.set_spinning(True)
                threading.Thread(target=self._import_worker,
                                 args=(Path(p),), daemon=True).start()

    def _import_worker(self, src: Path):
        try:
            eid = uuid.uuid4().hex[:8]
            dest = APPS_DIR / src.name
            if dest.exists():
                dest = APPS_DIR / f"{eid}-{src.name}"
            shutil.copy2(src, dest)
            os.chmod(dest, 0o755)
            meta = extract_meta(dest, eid)
            entry = {
                "id": eid,
                "name": meta["name"],
                "comment": meta["comment"],
                "filename": dest.name,
                "path": str(dest),
                "icon": meta["icon"],
                "wmclass": meta["wmclass"],
                "icon_scan": ICON_SCAN_VERSION,
                "installed": False,
                "desktop": None,
            }
            GLib.idle_add(self._finish_import, entry)
        except Exception:
            GLib.idle_add(self._finish_import, None)

    def _finish_import(self, entry):
        self._pending -= 1
        if self._pending <= 0:
            self.spinner.set_spinning(False)
        if entry:
            self.entries[entry["id"]] = entry
            self.save_db()
            self.refresh()
        return False

    # -------------------------------------------------- riparazione icone
    def _repair_icons(self):
        """Rianalizza (una sola volta) le voci senza icona importate con versioni precedenti."""
        todo = [dict(e) for e in self.entries.values()
                if e.get("icon_scan") != ICON_SCAN_VERSION
                and not (e.get("icon") and Path(e["icon"]).is_file())]
        if not todo:
            return
        self._pending += 1
        self.spinner.set_spinning(True)
        threading.Thread(target=self._repair_worker, args=(todo,), daemon=True).start()

    def _repair_worker(self, todo):
        results = []
        for e in todo:
            try:
                results.append((e["id"], extract_meta(Path(e["path"]), e["id"])))
            except Exception:
                results.append((e["id"], None))
        GLib.idle_add(self._finish_repair, results)

    def _finish_repair(self, results):
        self._pending -= 1
        if self._pending <= 0:
            self.spinner.set_spinning(False)
        for eid, meta in results:
            e = self.entries.get(eid)
            if e is None:                       # eliminata nel frattempo
                continue
            e["icon_scan"] = ICON_SCAN_VERSION
            if not meta:
                continue
            if meta.get("icon"):
                e["icon"] = meta["icon"]
            if meta.get("wmclass"):
                e["wmclass"] = meta["wmclass"]
            default = re.sub(r"(?i)\.appimage$", "", e.get("filename", ""))
            if meta.get("from_desktop") and e.get("name") in ("", default):
                e["name"] = meta["name"]
            if not e.get("comment") and meta.get("comment"):
                e["comment"] = meta["comment"]
            if e.get("installed"):
                self.install(e)                 # riscrive il .desktop con Icon=
        self.save_db()
        self.refresh()
        return False

    # -------------------------------------------------- installa / disinstalla / elimina
    def _desktop_path(self, eid):
        return DESKTOP_DIR / f"ruscahub-{eid}.desktop"

    def install(self, e):
        def clean(v):
            return " ".join(str(v or "").split())          # niente a capo nel .desktop
        dp = self._desktop_path(e["id"])
        lines = [
            "[Desktop Entry]",
            "Type=Application",
            f"Name={clean(e['name'])}",
            f"Comment={clean(e.get('comment')) or _('desktop_comment_default')}",
            f'Exec="{e["path"]}" %U',
            "Terminal=false",
            "Categories=Utility;",
            "X-RuscaHub=true",
        ]
        if e.get("icon") and Path(e["icon"]).is_file():
            lines.insert(4, f"Icon={e['icon']}")
        if e.get("wmclass"):
            # associa la finestra in esecuzione alla voce (icona corretta nella dash)
            lines.append(f"StartupWMClass={clean(e['wmclass'])}")
        dp.write_text("\n".join(lines) + "\n", encoding="utf-8")
        os.chmod(dp, 0o644)
        e["installed"] = True
        e["desktop"] = str(dp)
        if shutil.which("update-desktop-database"):
            subprocess.run(["update-desktop-database", str(DESKTOP_DIR)],
                           capture_output=True)

    def _remove_desktop(self, e):
        dp = Path(e.get("desktop") or self._desktop_path(e["id"]))
        if dp.is_file():
            dp.unlink()
        e["installed"] = False
        e["desktop"] = None

    def delete_entry(self, e):
        self._remove_desktop(e)
        try:
            Path(e["path"]).unlink(missing_ok=True)
        except OSError:
            pass
        if e.get("icon") and Path(e["icon"]).is_file():
            try:
                Path(e["icon"]).unlink()
            except OSError:
                pass
        self.entries.pop(e["id"], None)
        if shutil.which("update-desktop-database"):
            subprocess.run(["update-desktop-database", str(DESKTOP_DIR)],
                           capture_output=True)

    def launch(self, e):
        try:
            os.chmod(e["path"], 0o755)
        except OSError:
            pass
        try:
            subprocess.Popen([e["path"]], start_new_session=True,
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except OSError:  # fallback senza FUSE
            subprocess.Popen([e["path"], "--appimage-extract-and-run"],
                             start_new_session=True,
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    # -------------------------------------------------- UI
    def refresh(self):
        while True:
            row = self.listbox.get_first_child()
            if row is None:
                break
            self.listbox.remove(row)

        if not self.entries:
            self.stack.set_visible_child_name("empty")
            return
        self.stack.set_visible_child_name("list")

        for e in sorted(self.entries.values(), key=lambda x: x["name"].lower()):
            box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
            box.set_margin_top(10); box.set_margin_bottom(10)
            box.set_margin_start(12); box.set_margin_end(12)

            img = app_icon_widget(e.get("icon"), 48)
            box.append(img)

            vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
            nm = Gtk.Label(label=e["name"])
            nm.add_css_class("app-name")
            nm.set_halign(Gtk.Align.START)
            nm.set_ellipsize(Pango.EllipsizeMode.MIDDLE)
            vbox.append(nm)
            sb = Gtk.Label(label=f"{e['filename']}  •  {e['path']}")
            sb.add_css_class("app-sub")
            sb.set_halign(Gtk.Align.START)
            sb.set_ellipsize(Pango.EllipsizeMode.MIDDLE)
            vbox.append(sb)
            vbox.set_hexpand(True)
            box.append(vbox)

            chip = Gtk.Label(label=_("state_installed") if e["installed"] else _("state_archived"))
            chip.add_css_class("chip-yes" if e["installed"] else "chip-no")
            chip.set_valign(Gtk.Align.CENTER)
            box.append(chip)

            br = Gtk.Button.new_from_icon_name("media-playback-start-symbolic")
            br.add_css_class("run")
            br.set_tooltip_text(_("run_tooltip"))
            br.set_valign(Gtk.Align.CENTER)
            br.connect("clicked", lambda _b, e=e: self.launch(e))
            box.append(br)

            bi = Gtk.Button(label=_("uninstall") if e["installed"] else _("install"))
            bi.add_css_class("plum" if not e["installed"] else "flat-plum")
            bi.set_tooltip_text(_("install_tooltip"))
            bi.set_valign(Gtk.Align.CENTER)

            def on_toggle(_b, e=e):
                if e["installed"]:
                    self._remove_desktop(e)
                else:
                    self.install(e)
                self.save_db()
                self.refresh()
            bi.connect("clicked", on_toggle)
            box.append(bi)

            bd = Gtk.Button.new_from_icon_name("user-trash-symbolic")
            bd.add_css_class("trash")
            bd.set_tooltip_text(_("remove_tooltip"))
            bd.set_valign(Gtk.Align.CENTER)

            def on_del(_b, e=e):
                self.delete_entry(e)
                self.save_db()
                self.refresh()
            bd.connect("clicked", on_del)
            box.append(bd)

            row = Gtk.ListBoxRow()
            row.add_css_class("approw")
            row.set_selectable(False)
            row.set_activatable(False)
            row.set_child(box)
            self.listbox.append(row)

# ------------------------------------------------------------------ applicazione
class RuscaHubApp(Gtk.Application):
    def __init__(self):
        super().__init__(application_id=APP_ID,
                         flags=Gio.ApplicationFlags.DEFAULT_FLAGS)

    def do_startup(self):
        Gtk.Application.do_startup(self)
        if LANG in RTL_LANGS:
            Gtk.Widget.set_default_direction(Gtk.TextDirection.RTL)
        provider = Gtk.CssProvider()
        try:
            provider.load_from_string(CSS)
        except AttributeError:
            provider.load_from_data(CSS.encode(), -1)
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(), provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

    def do_activate(self):
        win = RuscaHubWindow(self)
        win.present()


if __name__ == "__main__":
    RuscaHubApp().run(None)