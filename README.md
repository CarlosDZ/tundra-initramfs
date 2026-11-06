# tundra-initramfs

Initramfs generator, developed for Tundra OS. It builds the image that mounts `/`
and hands over to systemd, and installs itself as the initrd generator of
`kernel-install`, so every kernel the package manager installs gets its image and
its systemd-boot entry.

The hardware is fixed, so is the image: `bash`, `mount`, `findfs`,
`switch_root`, `kmod` and `sleep` with their libraries, and the modules
`virtio_pci`, `virtio_blk` and `btrfs` with their dependencies and softdeps. NVMe
is built into the kernel.

## Requirements

- Linux on x86_64, with the loader at `/usr/lib/ld-linux-x86-64.so.2`.
- `bash`, `coreutils`, `findutils`, `util-linux`, `kmod` and `bsdtar`.
- `kernel-install` from systemd 259 or later, for the hooks.

## Usage

```
tundra-initramfs 6.18.37_1 /tmp/initrd
tundra-initramfs -b /mnt/new 6.18.37_1 /tmp/initrd
```

`-b` takes the modules from another tree, as `depmod -b`; the binaries always
come from the running system. The image is a `newc` cpio compressed with zstd,
readable only by root. Exit status: `0` built, `1` failed, `2` invalid usage.

The command line of the kernel is read by the init:

| Parameter | Meaning |
|-----------|---------|
| `root=` | `UUID=`, `LABEL=`, `PARTUUID=` or a `/dev` path, waited for up to 10 s |
| `rootflags=` | Mount options, such as `subvol=@,compress=zstd:3` |
| `rootfstype=` | File system type; detected when missing |
| `ro`, `rw` | Mount mode, `ro` by default |
| `init=` | Init of the root, `/sbin/init` by default |

If the root cannot be found or mounted, the init says why on the console and
starts a shell.

## Kernel hooks

| File | Role |
|------|------|
| `/etc/kernel.d/post-install/50-tundra-initramfs` | `kernel-install add` when xbps installs a kernel |
| `/etc/kernel.d/post-remove/50-tundra-initramfs` | `kernel-install remove` when it removes one |
| `/usr/lib/kernel/install.d/50-tundra-initramfs.install` | Writes the initrd to the staging area of `kernel-install` |
| `/usr/lib/kernel/install.conf.d/50-tundra-initramfs.conf` | `layout=bls` and `initrd_generator=tundra-initramfs` |

The command line of the entries comes from `/etc/kernel/cmdline`.

## Tests

```
make check-unit
make check
```

`check-unit` builds images for the running kernel and checks that every binary
runs with only the libraries of the image, and runs `kernel-install` with the
plugin against a temporary ESP; it needs user namespaces. `check` also boots the
newest `linux` package of `$TUNDRA_PKGS` (`~/void-packages/hostdir/binpkgs/tundra`
by default) in QEMU from a btrfs disk, with `root=UUID`, with a `/dev` path and
with a missing root; it needs `qemu-system-x86_64`, `mkfs.btrfs` and a static
libc.

## License

GPL-3.0-or-later.
