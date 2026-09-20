# Base image

**Directory:** `base/` · **Phase:** 0 · **Covers:** mkosi configuration, profiles, overlays, partition layout, image-time scripts

## Purpose

Produce a bootable, reproducible jinOs disk image from Debian 13 packages plus
first-party artifacts (`jincomp`, `jinshell`, `jind` from later phases).

## Layout

```
base/
├── mkosi.conf                 distribution, packages, boot, tools tree
├── mkosi.profiles/dev/        --profile=dev: openssh-server, sudo, passwords
│   ├── mkosi.conf
│   └── mkosi.extra/           dev-only overlay (sshd password login)
├── mkosi.extra/               overlay copied into every image (/etc/issue, networkd DHCP)
├── mkosi.repart/              systemd-repart partition definitions
└── mkosi.postinst.chroot      runs inside the image: creates user jin, enables units
```

Build with `make image` (see [dev-environment.md](../dev-environment.md)).
Outputs land in `build/`: `jinos.raw` (the disk), plus the UKI and kernel
mkosi extracts alongside it.

## What's in the image (Phase 0)

- **Kernel:** Debian's `linux-image-amd64` (6.12 LTS). A jinOs kernel config
  (DRM/KMS, virtio, binder) is a Phase 1 deliverable.
- **Boot:** systemd-boot on an ESP, kernel + initrd as a UKI. The initrd is
  mkosi's default initrd, not initramfs-tools.
- **Base:** systemd, udev, dbus-broker, systemd-networkd (DHCP on any
  ethernet), systemd-resolved, systemd-timesyncd, e2fsprogs/dosfstools,
  iproute2, procps, less, nano.
- **Console:** kernel command line `console=tty0 console=ttyS0,115200n8`, so
  gettys appear on both the graphical console and the serial port.
- **Users:** `jin` (uid 1000) created by the post-install script. No display
  manager; `jincomp` will run as `jin` from Phase 1.
- **Dev profile** (`--profile=dev`, the default in the Makefile): adds
  `openssh-server` and `sudo`, sets passwords `jinos` for `root` and `jin`,
  allows password SSH login, adds `jin` to `sudo`. SSH host keys are generated
  at build time, so every dev image shares them — acceptable for local VMs
  only. Release images never use this profile.

## Partition layout

Phase 0 (`mkosi.repart/`):

| Partition | Type | Size | Purpose |
|---|---|---|---|
| ESP | vfat | 512 MiB | systemd-boot + `EFI/Linux/*.efi` UKIs |
| root | ext4 (read-write) | 3 GiB | everything else |

Phase 5 replaces this with read-only A/B roots (erofs or squashfs) and a
separate data partition for `/home`, `/var`, `/etc/jinos`, Waydroid and
models; see [updates.md](updates.md).

## Reproducibility

`ToolsTree=default` makes mkosi build with a pinned Debian 13 tool set rather
than host tools, so native, container and CI builds produce the same image.
The package cache lives in `build/cache/`.

## Open items

- Trim the kernel-modules initrd (`KernelModulesInitrdInclude=`) once the
  Phase 1 kernel config exists; today every module ships in the UKI.
- Generate SSH host keys at first boot instead of build time.
- Set `IMAGE_VERSION` in `os-release` from git (needed by Phase 5 updates).
