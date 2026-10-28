#!/bin/bash
# ---------------------------------------------------------------------------
# RuscaLinux — costruisce il pacchetto ruscallama-engine.
#
#   ./make-deb.sh
#
# ruscallama-engine e' il motore che esegue i modelli linguistici per
# RuscaLLama e RuscaTranslator. E' llama.cpp, SOFTWARE ESTERNO (licenza MIT,
# https://github.com/ggml-org/llama.cpp), compilato dal sorgente con il
# backend Vulkan: un solo binario per NVIDIA, AMD e Intel, che ripiega sulla
# CPU quando non trova una scheda.
#
# Regole delle specifiche dei RuscaLinux OS Tools:
#   * versione del pacchetto = versione di RuscaLinux (release.conf);
#     la versione di llama.cpp e' fissata qui sotto e scritta nella
#     descrizione e nella documentazione del pacchetto;
#   * un solo .deb in build-deb/, con suffisso -ruscalinux e SHA256SUMS;
#   * architettura amd64: e' codice compilato, non Python.
#
# La compilazione e' lunga. Il risultato viene tenuto in una cache
# (~/.cache/ruscalinux/ruscallama-engine) e riusato finche' non cambiano
# versione di llama.cpp, backend o opzioni: le build successive della ISO
# rifanno solo il pacchetto, in pochi secondi.
#
# Variabili utili (facoltative):
#   RUSCALLAMA_BACKEND=cpu    compila senza Vulkan (prove, macchine senza GPU)
#   RUSCALLAMA_CACHE=<dir>    cartella della cache
#   RUSCALLAMA_JOBS=<n>       processi di compilazione (default: nproc)
#
# Dipendenze di compilazione:
#   sudo apt install build-essential cmake pkg-config dpkg-dev wget \
#                    libvulkan-dev glslc spirv-headers
# ---------------------------------------------------------------------------
set -euo pipefail
cd "$(dirname "$0")"
SRC_DIR="$(pwd)"

# ── Versioni ────────────────────────────────────────────────────────────────
VER="1.99.2"                       # = VERSION in release.conf
LLAMA_CPP_VERSION="0.6.0"          # tag v0.6.0 di llama.cpp
# Si aggiorna llama.cpp cambiando la riga qui sopra e aggiungendo in
# checksums/ l'impronta del nuovo archivio. Regola: usare una release
# pubblicata da almeno due settimane, provata con RuscaLLama e
# RuscaTranslator (le opzioni di llama-server cambiano tra le versioni).

PKG="ruscallama-engine"
ARCH="amd64"
MAINT="Nunzio Curcuruto <info@ruscalinux.org>"
HOMEPAGE="https://www.ruscalinux.org/"
UPSTREAM="https://github.com/ggml-org/llama.cpp"
BACKEND="${RUSCALLAMA_BACKEND:-vulkan}"
JOBS="${RUSCALLAMA_JOBS:-$(nproc)}"
CACHE="${RUSCALLAMA_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/ruscalinux/ruscallama-engine}"
SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-$(date +%s)}"

TAG="v${LLAMA_CPP_VERSION}"
ARCHIVE="llama.cpp-${TAG}.tar.gz"
URL="https://codeload.github.com/ggml-org/llama.cpp/tar.gz/refs/tags/${TAG}"
PIN="$SRC_DIR/checksums/${ARCHIVE}.sha256"
LIBDIR="usr/lib/${PKG}"            # binari e librerie private
PROFILE="usr.lib.ruscallama-engine.llama-server"

# Solo questi finiscono nel pacchetto: llama-server per i programmi,
# llama-cli e llama-bench per diagnosticare e misurare dal terminale.
KEEP_BINARIES="llama-server llama-cli llama-bench"

die() { echo "ERRORE: $*" >&2; exit 1; }
say() { echo "==> $*"; }

case "$BACKEND" in vulkan|cpu) ;; *) die "RUSCALLAMA_BACKEND deve essere vulkan o cpu";; esac
[ -f "$PIN" ] || die "manca l'impronta checksums/${ARCHIVE}.sha256"
[ -f "apparmor/$PROFILE" ] || die "manca il profilo apparmor/$PROFILE"

# ── Controllo delle dipendenze, prima di scaricare o compilare ──────────────
MANCA=""
for c in dpkg-deb dpkg-shlibdeps cmake g++ make pkg-config strip; do
    command -v "$c" >/dev/null || MANCA="$MANCA $c"
done
command -v wget >/dev/null || command -v curl >/dev/null || MANCA="$MANCA wget"
if [ "$BACKEND" = vulkan ]; then
    pkg-config --exists vulkan 2>/dev/null || MANCA="$MANCA libvulkan-dev"
    command -v glslc >/dev/null || MANCA="$MANCA glslc"
    find /usr -name 'SPIRV-HeadersConfig.cmake' -print -quit 2>/dev/null | grep -q . \
        || MANCA="$MANCA spirv-headers"
fi
if [ -n "$MANCA" ]; then
    echo "ERRORE: mancano strumenti per compilare llama.cpp:$MANCA" >&2
    echo "  sudo apt install build-essential cmake pkg-config dpkg-dev wget \\" >&2
    echo "                   libvulkan-dev glslc spirv-headers" >&2
    exit 1
fi

mkdir -p "$CACHE/src"
OUT_DIR="$SRC_DIR/build-deb"
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# ── Sorgente: cache locale, poi download, sempre con verifica dell'impronta ─
CACHED="$CACHE/src/$ARCHIVE"
if [ ! -f "$CACHED" ]; then
    say "Scarico llama.cpp $TAG"
    if command -v wget >/dev/null; then
        wget -q -O "$TMP/$ARCHIVE" "$URL" || die "download non riuscito ($URL)"
    else
        curl -sfL -o "$TMP/$ARCHIVE" "$URL" || die "download non riuscito ($URL)"
    fi
    mv "$TMP/$ARCHIVE" "$CACHED"
fi
ATTESO=$(cut -d' ' -f1 < "$PIN")
OTTENUTO=$(sha256sum "$CACHED" | cut -d' ' -f1)
if [ "$ATTESO" != "$OTTENUTO" ]; then
    rm -f "$CACHED"
    die "l'archivio di llama.cpp $TAG non corrisponde all'impronta registrata
        atteso:   $ATTESO
        ottenuto: $OTTENUTO
        Il file e' stato cancellato dalla cache: rilancia per riscaricarlo."
fi
say "Sorgente llama.cpp $TAG verificato"

# ── Compilazione (o riuso della cache) ───────────────────────────────────────
# GGML_NATIVE=OFF: il binario deve girare su qualunque x86-64, non solo sulla
#   macchina che costruisce la ISO.
# LLAMA_CURL=OFF: il motore non sa scaricare nulla da internet; i modelli
#   arrivano solo dai file scelti dall'utente (specifiche, privacy).
# Flag di hardening di Debian da dpkg-buildflags.
CFLAGS_DEB="$(dpkg-buildflags --get CFLAGS)"
CXXFLAGS_DEB="$(dpkg-buildflags --get CXXFLAGS)"
LDFLAGS_DEB="$(dpkg-buildflags --get LDFLAGS)"
CPPFLAGS_DEB="$(dpkg-buildflags --get CPPFLAGS)"
VULKAN_FLAG=$([ "$BACKEND" = vulkan ] && echo ON || echo OFF)
# La firma della cache non dipende dalla cartella in cui si lavora
# (dpkg-buildflags aggiunge -ffile-prefix-map=<cartella corrente>=.).
FLAGS_FIRMA=$(printf '%s %s' "$CFLAGS_DEB" "$LDFLAGS_DEB" | sed 's/-ffile-prefix-map=[^ ]*//g')
OPZIONI="tag=$TAG backend=$BACKEND native=OFF curl=OFF shared=ON flags=$FLAGS_FIRMA"
FIRMA=$(printf '%s' "$OPZIONI" | sha256sum | cut -c1-16)
STAGE_CACHE="$CACHE/stage-${LLAMA_CPP_VERSION}-${BACKEND}-${FIRMA}"

if [ -f "$STAGE_CACHE/.completo" ]; then
    say "Uso la compilazione in cache ($BACKEND)"
else
    say "Compilo llama.cpp $TAG ($BACKEND, $JOBS processi): ci vuole tempo"
    BUILD="$CACHE/build-${LLAMA_CPP_VERSION}-${BACKEND}-${FIRMA}"
    rm -rf "$BUILD" "$STAGE_CACHE"
    mkdir -p "$BUILD"
    tar -xzf "$CACHED" -C "$BUILD"
    SORG=$(find "$BUILD" -maxdepth 2 -name CMakeLists.txt -printf '%h\n' | head -1)
    [ -n "$SORG" ] || die "CMakeLists.txt non trovato nell'archivio"
    CFLAGS="$CFLAGS_DEB $CPPFLAGS_DEB" CXXFLAGS="$CXXFLAGS_DEB $CPPFLAGS_DEB" \
    LDFLAGS="$LDFLAGS_DEB" cmake -S "$SORG" -B "$SORG/build" \
        -DCMAKE_BUILD_TYPE=Release \
        -DGGML_VULKAN="$VULKAN_FLAG" \
        -DGGML_NATIVE=OFF \
        -DBUILD_SHARED_LIBS=ON \
        -DLLAMA_CURL=OFF \
        -DLLAMA_BUILD_TESTS=OFF \
        -DLLAMA_BUILD_EXAMPLES=OFF \
        -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON \
        -DCMAKE_INSTALL_RPATH="/${LIBDIR}"
    # shellcheck disable=SC2086
    cmake --build "$SORG/build" --config Release -j"$JOBS" --target $KEEP_BINARIES

    BIN=$(find "$SORG/build" -type f -name llama-server -printf '%h\n' | head -1)
    [ -n "$BIN" ] || die "llama-server non trovato dopo la compilazione"
    mkdir -p "$STAGE_CACHE/bin"
    # cp -a conserva i collegamenti simbolici delle librerie (libllama.so.0 ->
    # libllama.so.0.x.y) invece di duplicarle.
    for d in "$BIN" "$SORG/build/src" "$SORG/build/lib"; do
        [ -d "$d" ] && cp -a "$d"/*.so* "$STAGE_CACHE/bin/" 2>/dev/null || true
    done
    for b in $KEEP_BINARIES; do
        [ -f "$BIN/$b" ] && install -m 755 "$BIN/$b" "$STAGE_CACHE/bin/"
    done
    mkdir -p "$STAGE_CACHE/licenses"
    cp "$SORG/LICENSE" "$STAGE_CACHE/licenses/LICENSE.llama.cpp"
    touch "$STAGE_CACHE/.completo"
    rm -rf "$BUILD"
fi
[ -f "$STAGE_CACHE/bin/llama-server" ] || die "llama-server mancante nella compilazione"
# Le librerie si cercano solo nella cartella privata del pacchetto: un
# percorso della macchina di build nei binari sarebbe un errore.
if command -v readelf >/dev/null; then
    for f in "$STAGE_CACHE"/bin/*; do
        [ -L "$f" ] && continue
        RP=$(readelf -d "$f" 2>/dev/null | sed -n 's/.*R\(UN\)\?PATH.*\[\(.*\)\]/\2/p')
        [ -z "$RP" ] || [ "$RP" = "/$LIBDIR" ] || die "RUNPATH inatteso in $(basename "$f"): $RP"
    done
fi

# ── Albero del pacchetto ─────────────────────────────────────────────────────
ROOT="$TMP/${PKG}_${VER}_${ARCH}"
DOC="$ROOT/usr/share/doc/$PKG"
mkdir -p "$ROOT/DEBIAN" "$ROOT/$LIBDIR" "$DOC" \
         "$ROOT/etc/apparmor.d/force-complain"
cp -a "$STAGE_CACHE/bin/." "$ROOT/$LIBDIR/"
# Simboli di debug fuori dal pacchetto: decine di MB in meno nella ISO.
find "$ROOT/$LIBDIR" -type f \( -name '*.so*' -o -perm -u+x \) -exec \
    strip --strip-unneeded --remove-section=.comment --remove-section=.note {} \;
find "$ROOT/$LIBDIR" -type f -name '*.so*' -exec chmod 644 {} \;

# Controllo delle librerie: se ne manca una il motore non parte e i programmi
# vedono solo "terminato (codice 127)". Meglio scoprirlo qui.
MANCANTI=$(cd "$ROOT/$LIBDIR" && for f in $KEEP_BINARIES; do
    [ -f "$f" ] && LD_LIBRARY_PATH=. ldd "./$f" 2>/dev/null; done \
    | grep 'not found' | awk '{print $1}' | sort -u || true)
[ -z "$MANCANTI" ] || die "librerie non risolte: $MANCANTI"

# Profilo AppArmor, in modalita' complain (vedi il commento nel profilo).
install -m 644 "apparmor/$PROFILE" "$ROOT/etc/apparmor.d/$PROFILE"
ln -s "../$PROFILE" "$ROOT/etc/apparmor.d/force-complain/$PROFILE"
if command -v apparmor_parser >/dev/null 2>&1; then
    apparmor_parser -Q -K "apparmor/$PROFILE" >/dev/null \
        || die "il profilo AppArmor non e' valido"
fi

# ── Documentazione ───────────────────────────────────────────────────────────
cat > "$DOC/README.md" <<README
# ruscallama-engine $VER

Motore di inferenza dei RuscaLinux OS Tools RuscaLLama e RuscaTranslator.

**Componente esterno:** llama.cpp $TAG — $UPSTREAM — licenza MIT,
copyright The ggml authors. RuscaLinux lo compila dal sorgente senza
modifiche al codice.

| Voce | Valore |
|---|---|
| Versione di llama.cpp | $LLAMA_CPP_VERSION |
| Backend | $BACKEND |
| Ottimizzazioni per CPU specifica | no (GGML_NATIVE=OFF) |
| Download da internet (libcurl) | no (LLAMA_CURL=OFF) |
| Percorso | /$LIBDIR |
| Programmi | $KEEP_BINARIES |

Il server viene avviato dai programmi solo su 127.0.0.1, con una chiave
di accesso temporanea. Il profilo AppArmor
/etc/apparmor.d/$PROFILE e' in modalita' complain.

Per provare il motore dal terminale:

    /$LIBDIR/llama-cli --version
    /$LIBDIR/llama-bench -m modello.gguf
README
gzip -9n "$DOC/README.md"

cat > "$DOC/copyright" <<'COPYRIGHT'
Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
Upstream-Name: llama.cpp
Upstream-Contact: https://github.com/ggml-org/llama.cpp/issues
Source: https://github.com/ggml-org/llama.cpp
Comment: ruscallama-engine is llama.cpp, an external component, built from
 unmodified source for RuscaLinux. Only the packaging (build script and
 AppArmor profile) is part of RuscaLinux.

Files: *
Copyright: 2023-2026 The ggml authors
License: MIT

Files: vendor/nlohmann/*
Copyright: 2013-2025 Niels Lohmann
License: MIT

Files: vendor/cpp-httplib/*
Copyright: 2017 yhirose
License: MIT

Files: vendor/hash/rotate-bits/*
Copyright: 2021 William Casarin
License: MIT

Files: vendor/hash/xxhash/*
Copyright: 2012-2021 Yann Collet
License: BSD-2-Clause

Files: vendor/hash/sha1/* vendor/hash/sha256/* vendor/stb/* vendor/sheredom/*
 vendor/miniaudio/*
Copyright: none (public domain)
License: public-domain
 These files are dedicated to the public domain by their authors
 (stb_image and miniaudio also offer MIT/MIT-0 as an alternative).

Files: debian/* etc/apparmor.d/*
Copyright: 2026 Nunzio Curcuruto
License: GPL-3+
Comment: Design, specifications and testing by the author; code written
 with the assistance of AI tools. See NOTA-IA.md in the RuscaLinux repository.

License: MIT
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 .
 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.
 .
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.

License: BSD-2-Clause
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 .
 1. Redistributions of source code must retain the above copyright notice,
    this list of conditions and the following disclaimer.
 2. Redistributions in binary form must reproduce the above copyright notice,
    this list of conditions and the following disclaimer in the documentation
    and/or other materials provided with the distribution.
 .
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.

License: GPL-3+
 This program is free software: you can redistribute it and/or modify it
 under the terms of the GNU General Public License as published by the Free
 Software Foundation, either version 3 of the License, or (at your option)
 any later version.
 .
 On Debian systems, the complete text of the GNU General Public License
 version 3 can be found in "/usr/share/common-licenses/GPL-3".
COPYRIGHT
install -m 644 "$STAGE_CACHE/licenses/LICENSE.llama.cpp" "$DOC/LICENSE.llama.cpp"

cat <<CHANGELOG | gzip -9n > "$DOC/changelog.gz"
$PKG ($VER) unstable; urgency=medium

  * llama.cpp $TAG compilato dal sorgente (backend $BACKEND),
    senza libcurl.
  * Binari e librerie in /$LIBDIR
    (prima in /opt/ruscallama/bin).
  * Versione del pacchetto allineata a RuscaLinux; un solo .deb in
    build-deb/ con SHA256SUMS.
  * Compilazione in cache tra una build e l'altra.
  * Profilo AppArmor aggiornato al nuovo percorso, sempre in complain.

 -- $MAINT  $(LC_ALL=C date -Ru -d "@$SOURCE_DATE_EPOCH")
CHANGELOG

# ── Dipendenze calcolate dai binari ──────────────────────────────────────────
mkdir -p "$TMP/shlib/debian"
printf 'Source: %s\n\nPackage: %s\nArchitecture: %s\n' "$PKG" "$PKG" "$ARCH" \
    > "$TMP/shlib/debian/control"
SHLIBS=$(cd "$TMP/shlib" && dpkg-shlibdeps -O -l"$ROOT/$LIBDIR" \
    -e"$ROOT/$LIBDIR/llama-server" -e"$ROOT/$LIBDIR/llama-cli" \
    -e"$ROOT/$LIBDIR/llama-bench" \
    $(find "$ROOT/$LIBDIR" -type f -name '*.so*' -printf ' -e%p') 2>/dev/null \
    | sed -n 's/^shlibs:Depends=//p')
[ -n "$SHLIBS" ] || die "dpkg-shlibdeps non ha calcolato le dipendenze"
RECOMMENDS="apparmor"
[ "$BACKEND" = vulkan ] && RECOMMENDS="mesa-vulkan-drivers, $RECOMMENDS"

cat > "$ROOT/DEBIAN/control" <<CONTROL
Package: $PKG
Version: $VER
Section: science
Priority: optional
Architecture: $ARCH
Depends: $SHLIBS
Recommends: $RECOMMENDS
Maintainer: $MAINT
Homepage: $HOMEPAGE
Installed-Size: $(du -sk --exclude=DEBIAN "$ROOT" | cut -f1)
Description: language model engine for RuscaLLama and RuscaTranslator
 Runs local language models (GGUF files) for the RuscaLinux OS Tools
 RuscaLLama and RuscaTranslator. Contains llama-server, plus llama-cli
 and llama-bench for diagnostics.
 .
 This is llama.cpp $TAG, an external component (MIT license,
 $UPSTREAM), built from unmodified source with the
 $BACKEND backend and without network download support. Vulkan covers
 NVIDIA, AMD and Intel graphics with one binary and falls back to the CPU.
CONTROL

cat > "$ROOT/DEBIAN/conffiles" <<CONFFILES
/etc/apparmor.d/$PROFILE
CONFFILES

cat > "$ROOT/DEBIAN/postinst" <<POSTINST
#!/bin/sh
set -e
if [ "\$1" = "configure" ] && command -v apparmor_parser >/dev/null 2>&1 \\
        && aa-enabled --quiet 2>/dev/null; then
    apparmor_parser -r -T -W /etc/apparmor.d/$PROFILE || true
fi
POSTINST
cat > "$ROOT/DEBIAN/postrm" <<POSTRM
#!/bin/sh
set -e
if [ "\$1" = "remove" ] && command -v apparmor_parser >/dev/null 2>&1; then
    apparmor_parser -R /etc/apparmor.d/$PROFILE 2>/dev/null || true
fi
POSTRM
chmod 755 "$ROOT/DEBIAN/postinst" "$ROOT/DEBIAN/postrm"
find "$ROOT" -type d -exec chmod 755 {} +

# ── Costruzione ──────────────────────────────────────────────────────────────
DEB_FILE="${PKG}-ruscalinux_${VER}_${ARCH}.deb"
dpkg-deb --root-owner-group -Zxz --build "$ROOT" "$OUT_DIR/$DEB_FILE" >/dev/null
( cd "$OUT_DIR" && sha256sum "$DEB_FILE" > SHA256SUMS )
say "Pronto: build-deb/$DEB_FILE ($(du -h "$OUT_DIR/$DEB_FILE" | cut -f1)), llama.cpp $TAG, $BACKEND"
if command -v lintian >/dev/null 2>&1; then
    lintian --suppress-tags dir-or-file-in-opt "$OUT_DIR/$DEB_FILE" || true
fi
