PASS=0
FAIL=0
GEN=src/tundra-initramfs
export TUNDRA_INITRAMFS_INIT=src/init
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

ok() {
	PASS=$((PASS + 1))
	printf 'ok - %s\n' "$1"
}

not_ok() {
	FAIL=$((FAIL + 1))
	printf 'not ok - %s\n' "$1"
}

check() {
	desc=$1
	shift
	if "$@" >/dev/null 2>&1; then
		ok "$desc"
	else
		not_ok "$desc"
	fi
}

summary() {
	printf '# %d passed, %d failed\n' "$PASS" "$FAIL"
	[ "$FAIL" -eq 0 ]
}

# Paths of an image, without the leading ./
listing() {
	bsdtar -tf "$1" | sed 's|^\./||'
}

has() {
	listing "$1" | grep -qx "$2"
}
