# Base image

**Directory:** `base/` · **Phase:** 0 · **Covers:** kernel config, mkosi profiles, systemd units, overlays

## Purpose

Produce a bootable, reproducible jinOs disk image from Debian 13 packages plus first-party artifacts (`jincomp`, `jinshell`, `jind`).

## Contents

- `mkosi.conf` and `mkosi.conf.d/` — distribution, package list, output format (GPT disk with ESP + A/B root + data partition), profiles (`dev`, `release`, `installer`).
- `kernel/` — Debian kernel package selection now; a custom `.config` fragment from Phase 1 enabling DRM/KMS, virtio-gpu/net/blk/input, `CONFIG_ANDROID_BINDER_IPC`, `CONFIG_ANDROID_BINDERFS`, and disabling what jinOs never uses.
- `overlay/` — files copied verbatim into the image: `/etc/jinos/`, systemd units, compositor session config.
- `units/` — `jincomp.service`, `jind.service`, `waydroid-container.service` drop-ins.

## Package set (Phase 0–2 baseline)

systemd, systemd-boot, linux-image (LTS), seatd, pipewire + wireplumber, network-manager, dbus-broker, xdg-desktop-portal (+ a jinOs backend later), cage, foot, a browser (Firefox ESR or Chromium), openssh-server (dev profile only), waydroid (Phase 4), mesa (virgl + llvmpipe).

## Users and sessions

Single user `jin` (uid 1000) with a systemd user session; `jincomp` runs as `jin` on seat0 via seatd. `jind` runs as a dedicated system user with a D-Bus policy restricting its API to `jin`. No root login; `sudo` only in the `dev` profile.

## Partition layout (from Phase 5; designed for from Phase 0)

| Partition | Type | Purpose |
|---|---|---|
| ESP | vfat | systemd-boot, UKIs for slot A and B |
| root-A | erofs or squashfs (read-only) | current system |
| root-B | same | next/previous system |
| data | ext4 or btrfs | `/home`, `/var`, `/etc/jinos`, Waydroid data, models |

Until Phase 5 the `dev` profile uses a single read-write root to keep iteration fast.

## Open items

- UKIs from day one, or plain kernel + initrd in Phase 0.
- erofs vs squashfs for the read-only root.
