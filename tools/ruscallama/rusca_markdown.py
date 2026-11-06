"""RuscaLinux OS Tools — rusca_markdown.py — 1.99.2 — GPL-3.0

Markdown delle risposte dei modelli -> blocchi con markup Pango.
Modulo puro, senza GTK: si può provare con python3 da solo.

Blocchi restituiti da parse_blocks():
    ("text", markup)                         paragrafo, titolo, elenco, citazione
    ("code", lingua, sorgente)               blocco ``` (anche non chiuso)
    ("math", markup)                         formula su riga propria: $$…$$ o \\[…\\]
    ("table", allineamenti, intestazione, righe)   celle già in markup
    ("hr",)                                  linea orizzontale --- *** ___

Le formule LaTeX diventano testo Unicode (², ≈, √, α, ⁄ …) con <sup>/<sub>
di Pango dove Unicode non basta: nessuna dipendenza in più.
"""

import re

__all__ = ["parse_blocks", "inline_to_pango", "latex_to_pango", "escape", "plain_text"]


def escape(s):
    return (s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
            .replace('"', "&quot;").replace("'", "&#39;"))


def plain_text(markup):
    """Testo visibile di un markup (per misure e per il ripiego)."""
    s = re.sub(r"<[^>]+>", "", markup)
    return (s.replace("&lt;", "<").replace("&gt;", ">").replace("&quot;", '"')
            .replace("&#39;", "'").replace("&amp;", "&"))


# ── LaTeX -> Unicode / Pango ────────────────────────────────────────────────
_SYMBOLS = {
    # lettere greche
    "alpha": "α", "beta": "β", "gamma": "γ", "delta": "δ", "epsilon": "ε",
    "varepsilon": "ε", "zeta": "ζ", "eta": "η", "theta": "θ", "vartheta": "ϑ",
    "iota": "ι", "kappa": "κ", "lambda": "λ", "mu": "μ", "nu": "ν", "xi": "ξ",
    "pi": "π", "varpi": "ϖ", "rho": "ρ", "varrho": "ϱ", "sigma": "σ",
    "varsigma": "ς", "tau": "τ", "upsilon": "υ", "phi": "φ", "varphi": "φ",
    "chi": "χ", "psi": "ψ", "omega": "ω", "Gamma": "Γ", "Delta": "Δ",
    "Theta": "Θ", "Lambda": "Λ", "Xi": "Ξ", "Pi": "Π", "Sigma": "Σ",
    "Upsilon": "Υ", "Phi": "Φ", "Psi": "Ψ", "Omega": "Ω",
    # operatori e relazioni
    "times": "×", "cdot": "·", "div": "÷", "pm": "±", "mp": "∓", "ast": "∗",
    "approx": "≈", "simeq": "≃", "sim": "∼", "cong": "≅", "equiv": "≡",
    "neq": "≠", "ne": "≠", "leq": "≤", "le": "≤", "geq": "≥", "ge": "≥",
    "ll": "≪", "gg": "≫", "propto": "∝", "infty": "∞", "partial": "∂",
    "nabla": "∇", "sum": "∑", "prod": "∏", "int": "∫", "iint": "∬",
    "oint": "∮", "sqrt": "√", "in": "∈", "notin": "∉", "ni": "∋",
    "subset": "⊂", "subseteq": "⊆", "supset": "⊃", "supseteq": "⊇",
    "cup": "∪", "cap": "∩", "emptyset": "∅", "varnothing": "∅",
    "forall": "∀", "exists": "∃", "neg": "¬", "land": "∧", "lor": "∨",
    "wedge": "∧", "vee": "∨", "oplus": "⊕", "otimes": "⊗", "circ": "∘",
    "bullet": "•", "star": "⋆", "dagger": "†", "perp": "⊥", "parallel": "∥",
    "angle": "∠", "degree": "°", "prime": "′", "hbar": "ħ", "ell": "ℓ",
    "Re": "ℜ", "Im": "ℑ", "aleph": "ℵ",
    # frecce
    "to": "→", "rightarrow": "→", "leftarrow": "←", "gets": "←",
    "leftrightarrow": "↔", "Rightarrow": "⇒", "Leftarrow": "⇐",
    "Leftrightarrow": "⇔", "implies": "⇒", "iff": "⇔", "mapsto": "↦",
    "uparrow": "↑", "downarrow": "↓", "longrightarrow": "⟶",
    # puntini e parentesi
    "ldots": "…", "dots": "…", "cdots": "⋯", "vdots": "⋮", "ddots": "⋱",
    "langle": "⟨", "rangle": "⟩", "lfloor": "⌊", "rfloor": "⌋",
    "lceil": "⌈", "rceil": "⌉", "vert": "|", "Vert": "‖", "mid": "|",
    "lbrace": "{", "rbrace": "}",
    # spazi
    "quad": "\u2003", "qquad": "\u2003\u2003",
}
# Comandi di sola presentazione: si ignorano.
_DROP = {"Large", "large", "LARGE", "huge", "Huge", "small", "normalsize",
         "displaystyle", "textstyle", "scriptstyle", "left", "right", "big",
         "Big", "bigg", "Bigg", "bigl", "bigr", "Bigl", "Bigr", "limits",
         "nolimits", "nonumber", "notag"}
# Comandi con argomento da mostrare come testo.
_TEXTLIKE = {"text", "textrm", "textnormal", "mathrm", "operatorname", "mbox",
             "textit", "mathit", "textsf", "mathsf", "texttt", "mathtt",
             "mathbf", "textbf", "boldsymbol", "bm", "mathcal", "mathscr",
             "mathbb", "mathfrak", "hat", "bar", "vec", "dot", "ddot", "tilde",
             "overline", "underline", "widehat", "widetilde", "overrightarrow"}
_ACCENTS = {"hat": "\u0302", "bar": "\u0304", "overline": "\u0305", "vec": "\u20d7",
            "dot": "\u0307", "ddot": "\u0308", "tilde": "\u0303",
            "widehat": "\u0302", "widetilde": "\u0303", "overrightarrow": "\u20d7"}
_BB = {"R": "ℝ", "N": "ℕ", "Z": "ℤ", "Q": "ℚ", "C": "ℂ", "P": "ℙ", "H": "ℍ"}
_SUP = dict(zip("0123456789+-=()aeinx", "⁰¹²³⁴⁵⁶⁷⁸⁹⁺⁻⁼⁽⁾ᵃᵉⁱⁿˣ"))
_SUB = dict(zip("0123456789+-=()aehijklmnoprstuvx", "₀₁₂₃₄₅₆₇₈₉₊₋₌₍₎ₐₑₕᵢⱼₖₗₘₙₒₚᵣₛₜᵤᵥₓ"))
_SUP["−"], _SUB["−"] = "⁻", "₋"


class _Latex:
    def __init__(self, src):
        self.s = src
        self.i = 0

    def run(self, stop=None):
        out = []
        s = self.s
        while self.i < len(s):
            ch = s[self.i]
            if stop and ch == stop:
                self.i += 1
                break
            if ch == "\\":
                out.append(self._command())
            elif ch == "{":
                self.i += 1
                out.append(self.run("}"))
            elif ch in "^_":
                self.i += 1
                out.append(self._script(ch))
            elif ch == "~":
                self.i += 1
                out.append("\u00a0")
            elif ch == "&":
                self.i += 1
                out.append(" ")
            elif ch == "'":
                self.i += 1
                out.append("′")
            elif ch == "-":
                self.i += 1
                out.append("−")
            else:
                self.i += 1
                out.append(escape(ch))
        return "".join(out)

    def _group_src(self):
        """Sorgente del prossimo argomento: {gruppo}, \\comando o un carattere."""
        s = self.s
        while self.i < len(s) and s[self.i] == " ":
            self.i += 1
        if self.i >= len(s):
            return ""
        if s[self.i] == "{":
            depth, start = 0, self.i
            while self.i < len(s):
                if s[self.i] == "\\":
                    self.i += 2
                    continue
                if s[self.i] == "{":
                    depth += 1
                elif s[self.i] == "}":
                    depth -= 1
                    if depth == 0:
                        self.i += 1
                        return s[start + 1:self.i - 1]
                self.i += 1
            return s[start + 1:]
        if s[self.i] == "\\":
            m = re.match(r"\\([A-Za-z]+|.)", s[self.i:])
            self.i += m.end() if m else 1
            return m.group(0) if m else ""
        self.i += 1
        return s[self.i - 1]

    def _arg(self):
        return _Latex(self._group_src()).run()

    def _script(self, kind):
        markup = self._arg()
        text = plain_text(markup)
        table = _SUP if kind == "^" else _SUB
        if text and "<" not in markup and all(c in table for c in text):
            return "".join(table[c] for c in text)
        tag = "sup" if kind == "^" else "sub"
        return f"<{tag}>{markup}</{tag}>"

    def _command(self):
        s = self.s
        m = re.match(r"\\([A-Za-z]+)\*?", s[self.i:])
        if not m:                                   # \, \; \{ \\ …
            ch = s[self.i + 1:self.i + 2]
            self.i += 2
            if ch in ",:;>":
                return "\u2009"
            if ch == "!":
                return ""
            if ch == "\\":
                return "\n"
            if ch == " ":
                return " "
            return escape(ch)
        name = m.group(1)
        self.i += m.end()
        if name in _DROP:
            return ""
        if name in ("frac", "dfrac", "tfrac", "cfrac"):
            num, den = self._arg(), self._arg()
            wrap = lambda x: f"({x})" if re.search(r"[\s+−=·×/]", plain_text(x)) else x
            return f"{wrap(num)}⁄{wrap(den)}"
        if name == "sqrt":
            index = ""
            if self.s[self.i:self.i + 1] == "[":
                end = self.s.find("]", self.i)
                if end > 0:
                    index = _Latex(self.s[self.i + 1:end]).run()
                    self.i = end + 1
            body = self._arg()
            pre = "".join(_SUP.get(c, c) for c in plain_text(index)) if index else ""
            return pre + "√" + (body if len(plain_text(body)) <= 1 else f"({body})")
        if name in ("binom", "tbinom", "dbinom"):
            a, b = self._arg(), self._arg()
            return f"C({a}, {b})"
        if name in _TEXTLIKE:
            src = self._group_src()
            if name == "mathbb":
                return "".join(_BB.get(c, escape(c)) for c in src)
            if name in _ACCENTS:
                body = _Latex(src).run()
                return body + _ACCENTS[name] if len(plain_text(body)) == 1 else body
            if name in ("text", "textrm", "textnormal", "mbox", "texttt", "textit"):
                body = escape(src)                  # testo: niente comandi dentro
            else:
                body = _Latex(src).run()
            if name in ("mathbf", "textbf", "boldsymbol", "bm"):
                return f"<b>{body}</b>"
            if name in ("textit", "mathit"):
                return f"<i>{body}</i>"
            if name in ("texttt", "mathtt"):
                return f"<tt>{body}</tt>"
            return body
        if name in ("begin", "end"):
            self._group_src()                       # nome dell'ambiente
            return ""
        if name in _SYMBOLS:
            return _SYMBOLS[name]
        return escape(name)                         # \sin, \log, \max …


def latex_to_pango(src):
    """Formula LaTeX -> markup Pango leggibile."""
    try:
        return _Latex(src.strip()).run().strip()
    except Exception:                               # mai far sparire il testo
        return escape(src)


# ── Testo in linea ──────────────────────────────────────────────────────────
_RE_INLINE_MATH = re.compile(
    r"\$\$(.+?)\$\$"                                # $$…$$ dentro una frase
    r"|\\\((.+?)\\\)"                               # \(…\)
    r"|(?<![\\$\w])\$(?=\S)([^$\n]+?)(?<=\S)\$(?![\d$])")   # $…$ (non $5 e $10)
_RE_CODE_SPAN = re.compile(r"(`+)(.+?)\1")
_RE_ESCAPED = re.compile(r"\\([\\`*_{}\[\]()#+\-.!|>~$])")


def inline_to_pango(text):
    """Grassetto, corsivo, barrato, codice, link e formule in linea.

    Codice e formule sono messi da parte prima dell'escape, così gli
    asterischi di a*b o di \\text{…} non diventano corsivo."""
    keep = []

    def stash(markup):
        keep.append(markup)
        return f"\x00{len(keep) - 1}\x00"

    text = _RE_CODE_SPAN.sub(lambda m: stash(f"<tt>{escape(m.group(2).strip())}</tt>"), text)
    text = _RE_INLINE_MATH.sub(
        lambda m: stash(latex_to_pango(m.group(1) or m.group(2) or m.group(3))), text)
    text = _RE_ESCAPED.sub(lambda m: stash(escape(m.group(1))), text)
    s = escape(text)
    s = re.sub(r"\*\*\*(?=\S)(.+?)(?<=\S)\*\*\*", r"<b><i>\1</i></b>", s)
    s = re.sub(r"\*\*(?=\S)(.+?)(?<=\S)\*\*", r"<b>\1</b>", s)
    s = re.sub(r"(?<!\w)__(?=\S)(.+?)(?<=\S)__(?!\w)", r"<b>\1</b>", s)
    s = re.sub(r"(?<![\w*])\*(?=[^\s*])([^*]+?)(?<=[^\s*])\*(?![\w*])", r"<i>\1</i>", s)
    s = re.sub(r"(?<![\w_])_(?=[^\s_])([^_]+?)(?<=[^\s_])_(?![\w_])", r"<i>\1</i>", s)
    s = re.sub(r"~~(?=\S)(.+?)(?<=\S)~~", r"<s>\1</s>", s)
    s = re.sub(r"\[([^\]]+)\]\((https?://[^)\s]+)\)",
               lambda m: f'<a href="{m.group(2)}">{m.group(1)}</a>', s)
    for _ in range(3):                              # segnaposto annidati
        s = re.sub(r"\x00(\d+)\x00", lambda m: keep[int(m.group(1))], s)
    return s


# ── Blocchi ─────────────────────────────────────────────────────────────────
_RE_FENCE = re.compile(r"^\s{0,3}(`{3,}|~{3,})\s*([^\s`]*)")
_RE_HR = re.compile(r"^\s{0,3}([-*_])(?:\s*\1){2,}\s*$")
_RE_HEADING = re.compile(r"^\s{0,3}(#{1,6})\s+(.*?)\s*#*\s*$")
_RE_TABLE_SEP = re.compile(r"^\s*\|?\s*:?-+:?\s*(\|\s*:?-+:?\s*)*\|?\s*$")
_RE_BULLET = re.compile(r"^(\s*)[-*+]\s+(\[[ xX]\]\s+)?(.*)$")
_RE_NUMBER = re.compile(r"^(\s*)(\d+)[.)]\s+(.*)$")
_HEADING_SIZE = ("xx-large", "x-large", "large", "large", "medium", "medium")


def _split_row(line):
    s = line.strip()
    if s.startswith("|"):
        s = s[1:]
    if s.endswith("|") and not s.endswith("\\|"):
        s = s[:-1]
    cells, cur, in_code, i = [], [], False, 0
    while i < len(s):
        ch = s[i]
        if ch == "\\" and s[i + 1:i + 2] == "|":
            cur.append("|")
            i += 2
            continue
        if ch == "`":
            in_code = not in_code
        if ch == "|" and not in_code:
            cells.append("".join(cur).strip())
            cur = []
        else:
            cur.append(ch)
        i += 1
    cells.append("".join(cur).strip())
    return cells


def _is_table(lines, i):
    if i + 1 >= len(lines) or "|" not in lines[i]:
        return False
    sep = lines[i + 1]
    if "-" not in sep or not _RE_TABLE_SEP.match(sep):
        return False
    return len(_split_row(lines[i])) == len(_split_row(sep))


def _aligns(sep):
    out = []
    for c in _split_row(sep):
        left, right = c.startswith(":"), c.endswith(":")
        out.append("center" if left and right else "right" if right else "left")
    return out


def _line_markup(line):
    m = _RE_HEADING.match(line)
    if m:
        size = _HEADING_SIZE[len(m.group(1)) - 1]
        return f'<span size="{size}" weight="bold">{inline_to_pango(m.group(2))}</span>'
    m = _RE_BULLET.match(line)
    if m:
        indent = "    " * (len(m.group(1).expandtabs(4)) // 2)
        task = m.group(2)
        mark = ("☑" if task.strip()[1] in "xX" else "☐") if task else "•"
        return f"{indent}{mark}  {inline_to_pango(m.group(3))}"
    m = _RE_NUMBER.match(line)
    if m:
        indent = "    " * (len(m.group(1).expandtabs(4)) // 2)
        return f"{indent}{m.group(2)}.  {inline_to_pango(m.group(3))}"
    if line.lstrip().startswith(">"):
        body = re.sub(r"^\s*(>\s?)+", "", line)
        return f"┃ <i>{inline_to_pango(body)}</i>"
    return inline_to_pango(line)


def _display_math(lines, i):
    """Formula su riga propria ($$…$$ o \\[…\\], anche su più righe):
    (sorgente, indice della riga dopo) oppure None se non c'è o non è chiusa."""
    stripped = lines[i].strip()
    for opener, closer in (("$$", "$$"), ("\\[", "\\]")):
        if not stripped.startswith(opener):
            continue
        rest = stripped[len(opener):]
        if rest.rstrip().endswith(closer):
            src = rest.rstrip()[:-len(closer)]
            return (src, i + 1) if src.strip() else None
        if closer in rest:
            return None                             # $$a$$ seguito da testo
        for j in range(i + 1, len(lines)):
            if closer in lines[j]:
                tail = lines[j][:lines[j].find(closer)]
                return " ".join([rest] + lines[i + 1:j] + [tail]), j + 1
        return None
    return None


def parse_blocks(text):
    """Divide il testo in blocchi (vedi l'intestazione del modulo).

    Funziona anche su testo incompleto, durante lo streaming: un blocco di
    codice non chiuso arriva fino alla fine, una formula $$ non chiusa resta
    testo finché non si chiude."""
    lines = text.replace("\r\n", "\n").split("\n")
    blocks, para = [], []

    def flush():
        if para:
            blocks.append(("text", "\n".join(_line_markup(l) for l in para)))
            para.clear()

    i, n = 0, len(lines)
    while i < n:
        line = lines[i]
        stripped = line.strip()
        fence = _RE_FENCE.match(line)
        if fence:
            flush()
            mark = fence.group(1)
            body, i = [], i + 1
            while i < n and not (lines[i].strip().startswith(mark[0] * len(mark))
                                 and set(lines[i].strip()) <= {mark[0]}):
                body.append(lines[i])
                i += 1
            blocks.append(("code", fence.group(2).lower(), "\n".join(body)))
            i += 1
            continue
        math = _display_math(lines, i)
        if math:
            flush()
            blocks.append(("math", latex_to_pango(math[0])))
            i = math[1]
            continue
        if _is_table(lines, i):
            flush()
            header = _split_row(line)
            ncol = len(header)
            aligns = (_aligns(lines[i + 1]) + ["left"] * ncol)[:ncol]
            rows, i = [], i + 2
            while i < n and lines[i].strip() and "|" in lines[i]:
                rows.append((_split_row(lines[i]) + [""] * ncol)[:ncol])
                i += 1
            blocks.append(("table", aligns, [inline_to_pango(h) for h in header],
                           [[inline_to_pango(c) for c in r] for r in rows]))
            continue
        if _RE_HR.match(line):
            flush()
            blocks.append(("hr",))
            i += 1
            continue
        if not stripped:
            flush()
            i += 1
            continue
        if _RE_HEADING.match(line):                 # un titolo è sempre un blocco
            flush()
            para.append(line)
            flush()
            i += 1
            continue
        para.append(line)
        i += 1
    flush()
    return blocks
