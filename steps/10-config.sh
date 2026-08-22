#!/bin/sh
# Directory di lavoro di live-build. Si chiama .work e non "ruscalinux"
# perche' il repository stesso ora si chiama ruscalinux: due livelli con lo
# stesso nome rendono illeggibili i percorsi e il .gitignore.
mkdir .work
cd .work
lb config \
  --iso-application "RuscaLinux" \
  --iso-preparer "Nunzio Curcuruto" \
  --iso-publisher "RuscaLinux" \
  --iso-volume "RuscaLinux @VERSION@ amd64" \
  --checksums sha256 \
  --image-name "ruscalinux-@VERSION@" \
  --distribution "trixie" \
  --architectures "amd64" \
  --archive-areas "main non-free-firmware" \
  --firmware-chroot "true" \
  --mirror-bootstrap "http://ftp.fr.debian.org/debian/" \
  --mirror-binary "http://ftp.fr.debian.org/debian/" \
  --binary-images "iso-hybrid" \
  --bootappend-live "boot=live components quiet splash timezone=UTC locales=en_US.UTF-8 keyboard-layouts=us hostname=ruscalinux username=user autologin noeject" \
  --bootappend-install "file=/cdrom/preseed.cfg" \
  --debian-installer "live" \
  --debian-installer-gui "true" \
  --debian-installer-distribution "trixie" \
  --cache "true" \
  --cache-indices "true"
