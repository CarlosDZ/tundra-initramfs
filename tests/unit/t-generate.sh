. tests/lib.sh

kver=$(uname -r)
img=$TMP/initramfs.img
root=$TMP/root

check "builds an image for the running kernel" "$GEN" "$kver" "$img"
check "zstd compressed" sh -c "od -An -tx1 -N4 '$img' | tr -d ' \n' | grep -qx 28b52ffd"
check "readable only by its owner" test "$(stat -c %a "$img")" = 600
check "every entry owned by root" sh -c "! bsdtar -tvf '$img' --numeric-owner | awk '\$3 != 0 || \$4 != 0' | grep -q ."
check "init is executable" sh -c "bsdtar -tvf '$img' ./init | grep -q '^-rwxr-xr-x'"
for link in bin:usr/bin sbin:usr/bin lib:usr/lib lib64:usr/lib; do
	check "${link%%:*} links to ${link#*:}" sh -c "bsdtar -tvf '$img' ./${link%%:*} | grep -q ' -> ${link#*:}\$'"
done
for dir in dev proc sys run sysroot; do
	check "$dir exists" has "$img" "$dir"
done
check "the module list" sh -c "bsdtar -xOf '$img' ./usr/lib/tundra-initramfs/modules | tr '\n' ' ' | grep -qx 'virtio_pci virtio_blk btrfs '"
check "modules.dep.bin for $kver" has "$img" "usr/lib/modules/$kver/modules.dep.bin"
check "modules.builtin for $kver" has "$img" "usr/lib/modules/$kver/modules.builtin"

mkdir -p "$root"
bsdtar -xf "$img" -C "$root"
for bin in bash mount switch_root findfs kmod modprobe sleep; do
	check "$bin runs with only the libraries of the image" \
		unshare -r chroot "$root" "/usr/bin/$bin" --version
done

check "no arguments is a usage error" sh -c "'$GEN'; [ \$? -eq 2 ]"
check "a kernel version with a slash is a usage error" sh -c "'$GEN' ../x '$TMP/bad.img'; [ \$? -eq 2 ]"
check "an unknown kernel fails" sh -c "'$GEN' 0.0.0-none '$TMP/none.img'; [ \$? -eq 1 ]"
check "and leaves no image behind" sh -c "! ls '$TMP' | grep -q '^none.img'"
check "a missing init fails" sh -c "TUNDRA_INITRAMFS_INIT=/nonexistent '$GEN' '$kver' '$TMP/noinit.img'; [ \$? -eq 1 ]"

summary
