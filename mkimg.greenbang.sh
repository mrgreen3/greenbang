#!/bin/sh

# Override section_kernels to use selective firmware
section_kernels() {
	local _f _a _pkgs
	local _firmware="linux-firmware-none linux-firmware-brcm linux-firmware-ath10k linux-firmware-rtlwifi linux-firmware-rtw89"
	for _f in $kernel_flavors; do
		_pkgs="linux-$_f wireless-regdb $_firmware $modloop_addons"
		for _a in $kernel_addons; do
			_pkgs="$_pkgs $_a-$_f"
		done
		local id=$( (echo "$initfs_features::$_hostkeys" ; apk fetch --root "$APKROOT" --simulate alpine-base $_pkgs | sort) | checksum)
		build_section kernel $ARCH $_f $id $_pkgs
	done
}

profile_greenbang() {
	title="GreenBang"
	desc="Alpine Linux with labwc Wayland desktop"
	profile_base
	profile_abbrev="GB"
	image_ext="iso"
	arch="x86_64"
	output_format="iso"
	kernel_flavors="lts"
	kernel_addons=""
	apkovl="genapkovl-greenbang.sh"
	hostname="greenbang"
	
	local _version="${GB_VERSION:-0.1.9-beta}"
	image_name="greenbang-${_version}"
	output_filename="greenbang-${_version}-x86_64.iso"

	apks="$(echo $apks | sed 's/tiny-cloud-alpine//')"
	apks="$(echo $apks | sed 's/openssh//')"
	apks="$(echo $apks | sed 's/dhcpcd//')"
	apks="$(echo $apks | sed 's/openntpd//')"
	apks="$(echo $apks | sed 's/network-extras//')"

	apks="$apks linux-firmware-none linux-firmware-brcm linux-firmware-ath10k linux-firmware-rtlwifi linux-firmware-rtw89"

	SCRIPTDIR="$(cd "$(dirname "$0")" && pwd)"
	_pkglist="$(grep -v '^#' "$SCRIPTDIR/packages.list" | grep -v '^$' | tr '\n' ' ')"
	apks="$apks $_pkglist"

	# Override boot parameters
	initfs_cmdline="modules=loop,squashfs,sd-mod,usb-storage quiet "
}
