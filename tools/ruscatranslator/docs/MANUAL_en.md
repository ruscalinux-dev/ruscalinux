# RuscaTranslator 1.99.2 — Manual

**Version** 1.99.2 · **Author** Nunzio Curcuruto · **Distribution** RuscaLinux ([ruscalinux.org](https://www.ruscalinux.org/)) · **License** GNU GPL v3 or later

RuscaTranslator translates **Markdown** documents between the fifteen official languages of RuscaLinux with a language model that runs **on this computer**, through **ruscallama-engine** (llama.cpp, an external component under the MIT license). Headings, lists, tables, code and links stay intact.

Languages: English, Simplified Chinese, Spanish, Hindi, Arabic, Brazilian Portuguese, Russian, Japanese, German, French, Italian, Korean, Indonesian, Turkish, Polish. The source language can be detected automatically: from the script for Chinese, Japanese, Korean, Arabic, Hindi and Russian, from the most frequent words for the others.

---

## 1. Requirements

- RuscaLinux or Debian Stable, GNOME;
- Python ≥ 3.10, GTK ≥ 4.18, libadwaita ≥ 1.7, GtkSourceView 5;
- the `ruscallama-engine` package and a **GGUF** model in `~/.local/share/ruscallama/models/` or `/usr/share/ruscallama/models/`. A **Gemma 4 MoE** model is recommended; RuscaTranslator picks it on its own when it finds one.

## 2. Translating a document

1. **Open** the document (Ctrl+O), drag it onto the **Original** pane, or paste the text.
2. Choose the **source language** (or leave **Detect language**), the **target language** and the **text type**.
3. Press **Translate** (Ctrl+Enter). The translation appears in the right pane as it is written; the bottom bar shows which part of the document is being translated, with **Stop** (Esc).
4. Review and correct the translation directly in the pane, then **Save** (Ctrl+S). The suggested name is `document.<language>.md`.

The engine starts on its own with the first translation and stops when the window closes. The document is split into parts of about 6000 characters, never inside a code block.

## 3. Text type

| Type | When to use it |
|---|---|
| General | Any text |
| Essays and non-fiction | Essays, articles, argumentative texts: connectives and academic tone |
| Literature | Fiction and poetry: images, rhythm and register |
| Dialogue | Speech: interjections, colloquial register |

The text type changes the instructions to the model and, between Italian and English, which final corrections apply.

## 4. Linguistic knowledge (Italian ↔ English)

Between Italian and English, RuscaTranslator adds a **linguistic RAG** (`raglin.py`). It can be turned off in **Preferences** (Ctrl+,).

- **Knowledge base**: idioms, false friends, pragmatics, terminology, connectives, metaphors, conventions. For each part of the document, the relevant entries are passed to the model as hints.
- **Document glossary**: recurring terms are translated once and kept the same across the whole document.
- **Translation memory**: when you save a reviewed translation, pairs of paragraphs become references for future translations (only if the number of paragraphs matches).
- **Leftover check**: if a part still contains source-language text, that part is translated again once.
- **Final corrections**: a few declared, general-purpose corrections, for example *smart working* → *remote work*. They never touch code, links or HTML; some apply only to certain text types.

You can add your own entries in `~/.config/ruscatranslator/rag/personale.json`. The format is described in `README-RAG.md`, in the package documentation.

## 5. Preferences

| Option | Effect |
|---|---|
| Model | Choice among the GGUF files found, or any file |
| Graphics Card (Vulkan) | Much faster; off by default because some drivers hang |
| CPU Threads | As many as the physical cores is recommended |
| Context | 8192 is enough for 6000-character parts |
| Linguistic Knowledge | The RAG described above |

Engine options apply when the engine restarts: a notice at the top offers **Restart Engine**.

## 6. Keyboard shortcuts

| Keys | Action |
|---|---|
| Ctrl+O | Open |
| Ctrl+S / Ctrl+Shift+S | Save / Save As |
| Ctrl+Enter | Translate |
| Esc | Stop |
| Ctrl+I | Swap languages |
| Ctrl+, | Preferences |
| Ctrl+? | Keyboard shortcuts |
| F10 | Main menu |
| Ctrl+W / Ctrl+Q | Close the window / Quit |

## 7. Privacy

- The engine listens only on **127.0.0.1**, on a free port, with a **temporary key** in `$XDG_RUNTIME_DIR/ruscallama/` (0600 permissions).
- No text is sent over the internet; the engine cannot download anything.
- Where data stays: settings and personal entries in `~/.config/ruscatranslator/`; translation memory and glossaries in `~/.local/share/ruscatranslator/`. They can be deleted at any time.

Translation is automatic: legal, medical or published texts need human review.

## 8. Troubleshooting

| Problem | What to do |
|---|---|
| "ruscallama-engine is not installed" | `sudo apt install ruscallama-engine` |
| "No model found" | Copy a GGUF into `~/.local/share/ruscallama/models/` or choose it in Preferences |
| The engine stops at once | **Engine Log** from the menu: memory is often the cause |
| Slow translation | Try **Graphics Card (Vulkan)** |
| Parts left in the original language | Translate again, or fix them by hand before saving |

Support: info@ruscalinux.org — The note on the use of AI tools is in the About window and in the `NOTA-IA.md` file of the repository.
