. tests/lib.sh

PLUGIN=$PWD/src/50-tundra-initramfs.install
kver=$(uname -r)
bin=$TMP/bin
mkdir -p "$bin" "$TMP/stage"
ln -s "$PWD/$GEN" "$bin/tundra-initramfs"
export TUNDRA_INITRAMFS_INIT=$PWD/src/init

# Runs the plugin as kernel-install does, with a fresh staging area.
plugin() {
	rm -rf "$TMP/stage"
	mkdir "$TMP/stage"
	env PATH="$bin:$PATH" KERNEL_INSTALL_STAGING_AREA="$TMP/stage" "$@"
}

staged() {
	plugin "$@" && test -s "$TMP/stage/initrd"
}

not_staged() {
	plugin "$@" && ! test -e "$TMP/stage/initrd"
}

check "add writes the initrd to the staging area" \
	staged env KERNEL_INSTALL_LAYOUT=bls "$PLUGIN" add "$kver" /entry /vmlinuz
check "also with the uki layout" \
	staged env KERNEL_INSTALL_LAYOUT=uki "$PLUGIN" add "$kver" /entry /vmlinuz
check "nothing with the layout other" \
	not_staged env KERNEL_INSTALL_LAYOUT=other "$PLUGIN" add "$kver" /entry /vmlinuz
check "nothing with another initrd generator" \
	not_staged env KERNEL_INSTALL_LAYOUT=bls KERNEL_INSTALL_INITRD_GENERATOR=dracut \
	"$PLUGIN" add "$kver" /entry /vmlinuz
check "nothing when the caller gives the initrds" \
	not_staged env KERNEL_INSTALL_LAYOUT=bls "$PLUGIN" add "$kver" /entry /vmlinuz /given
check "nothing on remove" \
	not_staged env KERNEL_INSTALL_LAYOUT=bls "$PLUGIN" remove "$kver" /entry

# The xbps hooks, with a kernel-install that records its arguments.
printf '#!/bin/sh\necho "$*" >"%s/args"\n' "$TMP" >"$bin/kernel-install"
chmod +x "$bin/kernel-install"
hook() {
	env PATH="$bin:$PATH" "$1" linux6.18 6.18.37_1 && grep -qx "$2" "$TMP/args"
}
check "the post-install hook adds the kernel of the package" \
	hook src/kernel.d/post-install "add 6.18.37_1 /boot/vmlinuz-6.18.37_1"
check "the post-remove hook removes it" hook src/kernel.d/post-remove "remove 6.18.37_1"
rm "$bin/kernel-install"

# kernel-install wants the ESP to be the root of a file system: a tmpfs in a
# user namespace, found through SYSTEMD_ESP_PATH.
image=/usr/lib/modules/$kver/vmlinuz
if ! command -v kernel-install >/dev/null || [ ! -f "$image" ]; then
	not_ok "kernel-install and $image"
	summary
	exit
fi
esp=$TMP/esp
conf=$TMP/conf
mkdir -p "$esp" "$conf"
cp src/install.conf "$conf/install.conf"
echo "root=UUID=0 rootflags=subvol=@ rw" >"$conf/cmdline"
unshare -rm bash -c '
	esp=$1 conf=$2 kver=$3 image=$4 plugin=$5 bin=$6 out=$7
	mount -t tmpfs tmpfs "$esp" || exit 1
	ki() {
		env PATH="$bin:$PATH" SYSTEMD_ESP_PATH="$esp" SYSTEMD_XBOOTLDR_PATH="$esp" \
			SYSTEMD_RELAX_ESP_CHECKS=1 SYSTEMD_RELAX_XBOOTLDR_CHECKS=1 \
			KERNEL_INSTALL_CONF_ROOT="$conf" \
			KERNEL_INSTALL_PLUGINS="$plugin /usr/lib/kernel/install.d/90-loaderentry.install" \
			kernel-install --entry-token=literal:tundra "$@"
	}
	ki --make-entry-directory=yes add "$kver" "$image"
	echo $? >"$out/add.rc"
	(cd "$esp" && find . -type f | sort) >"$out/add.files"
	cat "$esp"/loader/entries/*.conf >"$out/entry" 2>/dev/null
	ki remove "$kver"
	echo $? >"$out/remove.rc"
	(cd "$esp" && find . -type f | sort) >"$out/remove.files"
' _ "$esp" "$conf" "$kver" "$image" "$PLUGIN" "$bin" "$TMP"

check "kernel-install add with the plugin" grep -qx 0 "$TMP/add.rc"
check "puts the kernel on the ESP" grep -qx "./tundra/$kver/linux" "$TMP/add.files"
check "and the initrd of tundra-initramfs" grep -qx "./tundra/$kver/initrd" "$TMP/add.files"
check "with a BLS entry for the kernel" grep -Eq "^linux +/tundra/$kver/linux\$" "$TMP/entry"
check "and the initrd" grep -Eq "^initrd +/tundra/$kver/initrd\$" "$TMP/entry"
check "and the command line of the system" grep -Eq '^options +root=UUID=0 rootflags=subvol=@ rw$' "$TMP/entry"
check "kernel-install remove" grep -qx 0 "$TMP/remove.rc"
check "leaves no kernel, initrd or entry" test ! -s "$TMP/remove.files"

summary
