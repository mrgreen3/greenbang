#!/usr/bin/env bash
#
# Profile modified for GreenBang 
# by Mr Green [mrgreen@archbang.org]

iso_name="greenbang"
iso_label="GREENBANG_$(date +%d%m)"
iso_publisher="GreenBANG Project <https://www.archbang.org>"
iso_application="GreenBang Project Live/Rescue Iso"
iso_version="$(date +%d%m)"
install_dir="arch"
buildmodes=("iso")
bootmodes=('bios.syslinux.mbr' 'bios.syslinux.eltorito'
           'uefi-ia32.systemd-boot.esp' 'uefi-x64.systemd-boot.esp'
           'uefi-ia32.systemd-boot.eltorito' 'uefi-x64.systemd-boot.eltorito')
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '1M')
bootstrap_tarball_compression=('zstd' '-c' '-T0' '--auto-threads=logical' '--long' '-19')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/root"]="0:0:750"
  ["/root/.gnupg"]="0:0:700"
  ["/etc/skel/GB_Scripts/"]="0:0:755"
  ["/root/mvuser"]="0:0:755"
)
#bootstrap_tarball_compression=(gzip -cn9)
