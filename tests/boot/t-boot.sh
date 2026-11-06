. tests/lib.sh

PKGS=${TUNDRA_PKGS:-$HOME/void-packages/hostdir/binpkgs/tundra}
FAKE_INIT=build/test/tools/fake-init

kernel_pkg() {
	ls "$PKGS"/linux*.x86_64.xbps 2>/dev/null |
		grep -E '/linux[0-9.]+-[0-9][^/]*\.x86_64\.xbps$' | sort -V | tail -n1
}

xbps=$(kernel_pkg)
missing=
for cmd in qemu-system-x86_64 mkfs.btrfs bsdtar depmod modprobe timeout; do
	command -v "$cmd" >/dev/null || missing="$missing $cmd"
done
[ -n "$xbps" ] || missing="$missing linux-package-in-$PKGS"
[ -x "$FAKE_INIT" ] || missing="$missing $FAKE_INIT"
if [ -n "$missing" ]; then
	not_ok "boot prerequisites:$missing"
	summary
	exit
fi

kroot=$TMP/kernel
mkdir -p "$kroot"
bsdtar -xf "$xbps" -C "$kroot" ./boot ./usr/lib/modules
kver=$(ls "$kroot/usr/lib/modules")
printf '# kernel %s from %s\n' "$kver" "${xbps##*/}"

check "builds the image for the packaged kernel" \
	"$GEN" -b "$kroot" "$kver" "$TMP/initramfs.img"
check "with virtio_blk from the package" \
	has "$TMP/initramfs.img" "usr/lib/modules/$kver/kernel/drivers/block/virtio_blk.ko.zst"
check "and btrfs" \
	has "$TMP/initramfs.img" "usr/lib/modules/$kver/kernel/fs/btrfs/btrfs.ko.zst"

uuid=$(cat /proc/sys/kernel/random/uuid)
mkdir -p "$TMP/rootdir/@/sbin" "$TMP/rootdir/@/proc" "$TMP/rootdir/@/sys" \
	"$TMP/rootdir/@/dev" "$TMP/rootdir/@/run"
cp "$FAKE_INIT" "$TMP/rootdir/@/sbin/init"
truncate -s 256M "$TMP/root.img"
check "a btrfs disk with / in the subvolume @" \
	mkfs.btrfs -q -U "$uuid" --rootdir "$TMP/rootdir" --subvol @ "$TMP/root.img"

accel=()
[ -w /dev/kvm ] && accel=(-enable-kvm -cpu host)

# Boots the disk; the console, without the carriage returns of the serial
# line, ends up in $TMP/$1.log.
boot() {
	local name=$1 secs=$2 append=$3
	timeout "$secs" qemu-system-x86_64 -machine q35 -m 1024 -smp 2 \
		-nographic -no-reboot "${accel[@]}" \
		-kernel "$kroot/boot/vmlinuz-$kver" -initrd "$TMP/initramfs.img" \
		-append "console=ttyS0 panic=-1 $append" \
		-drive "file=$TMP/root.img,if=virtio,format=raw" \
		</dev/null 2>&1 | tr -d '\r' >"$TMP/$name.log"
	return "${PIPESTATUS[0]}"
}

saw() {
	grep -Eq "$2" "$TMP/$1.log"
}

check "boots with root=UUID and powers off" \
	boot uuid 120 "root=UUID=$uuid rootflags=subvol=@ rw"
check "the init of the disk runs" saw uuid '^tundra-test-init ok'
check "as PID 1" saw uuid '^tundra-test-pid 1$'
check "/ is the subvolume @ of the btrfs disk" \
	saw uuid '^tundra-test-root /dev/vda / btrfs .*subvol=/@'
check "read-write" saw uuid '^tundra-test-root /dev/vda / btrfs rw,'
check "virtio_pci loaded by the initramfs" saw uuid '^tundra-test-module virtio_pci '
check "virtio_blk loaded by the initramfs" saw uuid '^tundra-test-module virtio_blk '
check "btrfs loaded by the initramfs" saw uuid '^tundra-test-module btrfs '
check "no complaint from the initramfs" sh -c "! grep -q 'tundra-initramfs:' '$TMP/uuid.log'"
grep -q '^tundra-test-init ok' "$TMP/uuid.log" || sed 's/^/#   /' "$TMP/uuid.log" | tail -n 30

check "boots with root=/dev/vda" boot dev 120 "root=/dev/vda rootflags=subvol=@ ro"
check "read-only" saw dev '^tundra-test-root /dev/vda / btrfs ro,'

other=$(cat /proc/sys/kernel/random/uuid)
boot missing 25 "root=UUID=$other rootflags=subvol=@ rw"
check "a missing root ends in the rescue shell" \
	saw missing "tundra-initramfs: root UUID=$other not found; starting a shell"

summary
