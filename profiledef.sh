#!/bin/sh

export iso_label="GreenBang"
export iso_publisher="GreenBang"
export iso_version="0.1"
export output_filename="greenbang-${iso_version}-x86_64.iso"

case "$ARCH" in
	aarch64) export hostarch="aarch64" ;;
	*) export hostarch="x86_64" ;;
esac

arch_abbr() {
	case "$ARCH" in
		aarch64) echo "aarch64" ;;
		*) echo "x86_64" ;;
	esac
}

profile_abbr() {
	echo "greenbang"
}
