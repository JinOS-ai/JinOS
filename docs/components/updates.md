# Updates and installer

**Phase:** 5 · **Where:** `base/` (partition layout, sysupdate config), `shell/installer`

## Update model

A/B root partitions, read-only, updated as whole images:

1. A new image version is published (signed) to an HTTPS location.
2. `systemd-sysupdate` on the device downloads it into the inactive slot.
3. systemd-boot's boot counting marks the new entry; on reboot it is tried.
4. If the new slot fails to boot successfully a set number of times, the bootloader falls back to the previous slot automatically.
5. User data (`/home`, `/var`, `/etc/jinos`, Waydroid data, models) is on a separate partition and is untouched.

Settings → Updates shows current and available versions and lets the user trigger download/apply; automatic download with manual apply is the default.

**Alternative:** RAUC, if sysupdate proves too limited (delta updates, bootloader flexibility). Decision deferred until hands-on evaluation in Phase 5; the image format and partition layout are the same either way.

## Installer

An `installer` mkosi profile produces a live-USB image identical to a normal jinOs image but booting `jinshell` in installer mode:

1. Welcome → language / keyboard.
2. Choose target disk (whole-disk only in v0.1; clearly destructive warning).
3. Write partitions (`systemd-repart` definitions), copy the root image into slot A, create the data partition, write the ESP.
4. Create the `jin` user; set up Wi-Fi if available.
5. Reboot.

No dual-boot, no manual partitioning, no Secure Boot in v0.1 (document how to disable it).

## Versioning

Image version = `YYYY.MM.N` plus git commit, recorded in `/usr/lib/os-release` (`IMAGE_VERSION`). `sysupdate` matches on this.
