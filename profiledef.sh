profile_greenbang() {
	title="GreenBang"
	desc="Minimal Alpine Linux with Openbox desktop"
	profile_base
	profile_abbrev="GB"
	image_ext="iso"
	arch="x86_64"
	output_format="iso"
	kernel_flavors="lts"
	kernel_addons=""
	grub_mod="normal linux gzio part_gpt part_msdos"
	efi_mod="search iso9660 search_fs_uuid search_label gzio normal linux gpt fat part_gpt part_msdos"
	grub_cmdline="nomodeset"
	xorg_devices="vesa"
	apkovl="genapkovl-greenbang.sh"

	# GreenBang packages (minimal)
	apks="$apks openbox xterm"
	apks="$apks xorg-server xinit xf86-input-libinput xf86-video-vesa"
	apks="$apks bash sudo"
}
