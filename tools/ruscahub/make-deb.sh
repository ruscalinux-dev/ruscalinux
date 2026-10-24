#!/usr/bin/env bash
# make-deb.sh — Crea il pacchetto .deb di RuscaHub con SHA256SUMS
# Uso: ./make-deb.sh          (dalla radice del progetto)
# Output: build-deb/ruscahub-ruscalinux_<VER>_all.deb + build-deb/SHA256SUMS
set -euo pipefail

PKG="ruscahub"
VER="1.99.2"
ARCH="all"                     # solo Python: indipendente dall'architettura
SUFFIX="ruscalinux"            # suffisso obbligatorio (specifiche RuscaLinux)
MAINT="Nunzio Curcuruto <info@ruscalinux.org>"
HOMEPAGE="https://www.ruscalinux.org/"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="$ROOT_DIR/build-deb"
STAGE="$OUT/.staging/${PKG}_${VER}_${ARCH}"
trap 'rm -rf "$OUT/.staging"' EXIT

echo "== RuscaHub $VER — creazione pacchetto .deb =="

# ------------------------------------------------------------------ sorgenti
find_file() { local c; for c in "$@"; do [ -f "$ROOT_DIR/$c" ] && { echo "$ROOT_DIR/$c"; return 0; }; done; return 1; }
find_dir()  { local c; for c in "$@"; do [ -d "$ROOT_DIR/$c" ] && { echo "$ROOT_DIR/$c"; return 0; }; done; return 1; }

PY="$(find_file ruscahub/ruscahub.py ruscahub.py)"                || { echo "ERRORE: ruscahub.py non trovato"; exit 1; }
SVG="$(find_file ruscahub.svg data/ruscahub.svg ruscahub/ruscahub.svg org.ruscalinux.RuscaHub.svg)" || { echo "ERRORE: icona SVG non trovata"; exit 1; }
LANG_DIR="$(find_dir lang ruscahub/lang)"                         || { echo "ERRORE: cartella lang/ non trovata"; exit 1; }
[ -f "$LANG_DIR/en.json" ] || { echo "ERRORE: lang/en.json (fallback) mancante"; exit 1; }
[ -f "$LANG_DIR/it.json" ] || { echo "ERRORE: lang/it.json mancante"; exit 1; }
MAN_IT="$(find_file docs/MANUAL_it.md MANUAL_it.md)"             || MAN_IT=""
MAN_EN="$(find_file docs/MANUAL_en.md MANUAL_en.md)"             || MAN_EN=""

# Verifica sintattica dei file di traduzione (se python3 è disponibile)
if command -v python3 >/dev/null; then
    for j in "$LANG_DIR"/*.json; do
        python3 -c 'import json,sys; json.load(open(sys.argv[1], encoding="utf-8"))' "$j" \
            || { echo "ERRORE: JSON non valido: $j"; exit 1; }
    done
fi

# ------------------------------------------------------------------ struttura
rm -rf "$OUT/.staging"
mkdir -p "$STAGE/DEBIAN" \
         "$STAGE/usr/bin" \
         "$STAGE/usr/share/ruscahub/lang" \
         "$STAGE/usr/share/applications" \
         "$STAGE/usr/share/icons/hicolor/scalable/apps" \
         "$STAGE/usr/share/doc/ruscahub"

cp "$PY"  "$STAGE/usr/share/ruscahub/ruscahub.py"
cp "$LANG_DIR"/*.json "$STAGE/usr/share/ruscahub/lang/"
cp "$SVG" "$STAGE/usr/share/icons/hicolor/scalable/apps/org.ruscalinux.RuscaHub.svg"
[ -n "$MAN_IT" ] && cp "$MAN_IT" "$STAGE/usr/share/doc/ruscahub/MANUAL_it.md"
[ -n "$MAN_EN" ] && cp "$MAN_EN" "$STAGE/usr/share/doc/ruscahub/MANUAL_en.md"

# ------------------------------------------------------------------ launcher
cat > "$STAGE/usr/bin/ruscahub" <<'EOF'
#!/bin/sh
exec python3 /usr/share/ruscahub/ruscahub.py "$@"
EOF
chmod 755 "$STAGE/usr/bin/ruscahub"

# ------------------------------------------------------------------ desktop (15 lingue)
cat > "$STAGE/usr/share/applications/org.ruscalinux.RuscaHub.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=RuscaHub
GenericName=AppImage Manager
GenericName[it]=Gestore di AppImage
GenericName[de]=AppImage-Verwaltung
GenericName[fr]=Gestionnaire d'AppImage
GenericName[es]=Gestor de AppImage
GenericName[pt_BR]=Gerenciador de AppImage
GenericName[ru]=Менеджер AppImage
GenericName[zh_CN]=AppImage 管理器
GenericName[hi]=AppImage प्रबंधक
GenericName[ar]=مدير AppImage
GenericName[ja]=AppImage マネージャー
GenericName[ko]=AppImage 관리자
GenericName[id]=Pengelola AppImage
GenericName[tr]=AppImage Yöneticisi
GenericName[pl]=Menedżer AppImage
Comment=Manage, install and run AppImage packages
Comment[it]=Gestisci, installa ed esegui pacchetti AppImage
Comment[de]=AppImage-Pakete verwalten, installieren und ausführen
Comment[fr]=Gérer, installer et exécuter des paquets AppImage
Comment[es]=Gestionar, instalar y ejecutar paquetes AppImage
Comment[pt_BR]=Gerencie, instale e execute pacotes AppImage
Comment[ru]=Управление, установка и запуск пакетов AppImage
Comment[zh_CN]=管理、安装和运行 AppImage 软件包
Comment[hi]=AppImage पैकेज प्रबंधित करें, इंस्टॉल करें और चलाएँ
Comment[ar]=إدارة حزم AppImage وتثبيتها وتشغيلها
Comment[ja]=AppImage パッケージの管理、インストール、実行
Comment[ko]=AppImage 패키지 관리, 설치 및 실행
Comment[id]=Kelola, pasang, dan jalankan paket AppImage
Comment[tr]=AppImage paketlerini yönetin, kurun ve çalıştırın
Comment[pl]=Zarządzaj pakietami AppImage, instaluj je i uruchamiaj
Exec=ruscahub
Icon=org.ruscalinux.RuscaHub
Terminal=false
Categories=Utility;System;FileTools;
Keywords=AppImage;Manager;RuscaTools;
StartupWMClass=org.ruscalinux.RuscaHub
EOF

# ------------------------------------------------------------------ copyright
cat > "$STAGE/usr/share/doc/ruscahub/copyright" <<'EOF'
RuscaHub — AppImage manager for RuscaLinux (RuscaTools)
Copyright (C) 2026 Nunzio Curcuruto <info@ruscalinux.org>
License: GPL-3.0 — https://www.gnu.org/licenses/gpl-3.0.txt
Developed with the support of AI tools (Qwen): design, specifications,
review and editorial responsibility belong to the author.
EOF

# ------------------------------------------------------------------ maintainer scripts
cat > "$STAGE/DEBIAN/postinst" <<'EOF'
#!/bin/sh
set -e
if [ -x /usr/bin/update-desktop-database ]; then
    update-desktop-database /usr/share/applications || true
fi
if [ -x /usr/bin/gtk-update-icon-cache ]; then
    gtk-update-icon-cache -f -t /usr/share/icons/hicolor || true
fi
exit 0
EOF
cp "$STAGE/DEBIAN/postinst" "$STAGE/DEBIAN/postrm"
chmod 755 "$STAGE/DEBIAN/postinst" "$STAGE/DEBIAN/postrm"

# ------------------------------------------------------------------ permessi
find "$STAGE" -type d -exec chmod 755 {} +
find "$STAGE/usr/share" -type f -exec chmod 644 {} +

# ------------------------------------------------------------------ control + md5sums
INSTALLED_SIZE="$(du -sk --exclude=DEBIAN "$STAGE" | cut -f1)"
cat > "$STAGE/DEBIAN/control" <<EOF
Package: $PKG
Version: $VER
Section: utils
Priority: optional
Architecture: $ARCH
Installed-Size: $INSTALLED_SIZE
Depends: python3 (>= 3.10), python3-gi, python3-cairo, gir1.2-gtk-4.0
Recommends: squashfs-tools, libfuse2t64 | libfuse2
Suggests: fonts-noto-core, fonts-noto-cjk
Maintainer: $MAINT
Homepage: $HOMEPAGE
Description: AppImage manager for RuscaLinux (RuscaTools suite)
 RuscaHub imports AppImage files by drag and drop or file chooser, stores
 them in a hidden folder of the user home and integrates them into the
 GNOME menu through .desktop entries, with the original application icon.
 Install, uninstall, run and delete AppImages from a single pink-to-plum
 GTK4 interface, available in 15 languages.
EOF
chmod 644 "$STAGE/DEBIAN/control"
( cd "$STAGE" && find usr -type f -print0 | sort -z | xargs -0 md5sum ) > "$STAGE/DEBIAN/md5sums"
chmod 644 "$STAGE/DEBIAN/md5sums"

# ------------------------------------------------------------------ build
mkdir -p "$OUT"
DEB_NAME="${PKG}-${SUFFIX}_${VER}_${ARCH}.deb"
rm -f "$OUT/$DEB_NAME" "$OUT/SHA256SUMS"
dpkg-deb --build --root-owner-group "$STAGE" "$OUT/$DEB_NAME"

# ------------------------------------------------------------------ SHA256SUMS
( cd "$OUT" && sha256sum *.deb > SHA256SUMS )

echo
echo "== Completato =="
echo "Pacchetto : $OUT/$DEB_NAME"
echo "Checksum  : $OUT/SHA256SUMS"
cat "$OUT/SHA256SUMS"
echo
echo "Verifica  : cd build-deb && sha256sum -c SHA256SUMS"
echo "Install   : sudo apt install ./build-deb/$DEB_NAME"
