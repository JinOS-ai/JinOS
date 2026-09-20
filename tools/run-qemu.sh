#!/usr/bin/env bash
# Boot a jinOs disk image in QEMU. Used by `make run`, `make run-serial` and
# tools/boot-test.sh.
#
# Environment knobs:
#   JINOS_DISPLAY   gui (default) | none
#   JINOS_SERIAL    stdio (default, with the QEMU monitor on Ctrl-A C) | file:<path>
#   JINOS_PERSIST   1 = boot the image in place; default boots a throwaway
#                   qcow2 overlay so every `make run` starts from a clean image
#   JINOS_MEM       RAM in MiB (default 2048)
#   JINOS_CPUS      vCPUs (default 2)
#   JINOS_SSH_PORT  host port forwarded to guest port 22 (default 2222)
#   QEMU            qemu binary (default qemu-system-x86_64)
#   QEMU_EXTRA      extra arguments appended verbatim
set -euo pipefail

image=${1:-build/jinos.raw}
if [ ! -f "$image" ]; then
    echo "run-qemu: $image not found; run 'make image' first" >&2
    exit 1
fi
build_dir=$(cd "$(dirname "$image")" && pwd)
image_abs=$build_dir/$(basename "$image")

qemu=${QEMU:-qemu-system-x86_64}
if ! command -v "$qemu" >/dev/null 2>&1; then
    echo "run-qemu: $qemu not found. Install QEMU:" >&2
    echo "  Debian/Ubuntu: sudo apt install qemu-system-x86 qemu-utils ovmf" >&2
    echo "  macOS:         brew install qemu" >&2
    exit 1
fi

# --- acceleration ------------------------------------------------------------
# KVM on x86_64 Linux, HVF on Intel Macs, otherwise TCG (works everywhere,
# including Apple Silicon, just slower).
accel=tcg
cpu=max
case "$(uname -s):$(uname -m)" in
    Linux:x86_64)  if [ -w /dev/kvm ]; then accel=kvm; cpu=host; fi ;;
    Darwin:x86_64) accel=hvf; cpu=host ;;
esac

# --- UEFI firmware ------------------------------------------------------------
# systemd-boot needs UEFI. Look for OVMF/edk2 in the usual distro locations
# and next to the qemu binary (Homebrew).
qemu_share=$(cd "$(dirname "$(command -v "$qemu")")/../share/qemu" 2>/dev/null && pwd || true)
fw_code=
fw_vars=
for pair in \
    "/usr/share/OVMF/OVMF_CODE_4M.fd:/usr/share/OVMF/OVMF_VARS_4M.fd" \
    "/usr/share/OVMF/OVMF_CODE.fd:/usr/share/OVMF/OVMF_VARS.fd" \
    "/usr/share/edk2/x64/OVMF_CODE.4m.fd:/usr/share/edk2/x64/OVMF_VARS.4m.fd" \
    "/usr/share/edk2/ovmf/OVMF_CODE.fd:/usr/share/edk2/ovmf/OVMF_VARS.fd" \
    "/usr/share/qemu/edk2-x86_64-code.fd:/usr/share/qemu/edk2-i386-vars.fd" \
    "${qemu_share:-/nonexistent}/edk2-x86_64-code.fd:${qemu_share:-/nonexistent}/edk2-i386-vars.fd"
do
    code=${pair%%:*}
    vars=${pair#*:}
    if [ -f "$code" ]; then
        fw_code=$code
        [ -f "$vars" ] && fw_vars=$vars
        break
    fi
done
if [ -z "$fw_code" ]; then
    echo "run-qemu: no UEFI firmware found (install ovmf / edk2-ovmf, or brew's qemu ships it)" >&2
    exit 1
fi
fw_args=(-drive "if=pflash,format=raw,readonly=on,file=$fw_code")
if [ -n "$fw_vars" ]; then
    # Writable copy so systemd-boot can store EFI variables across runs.
    [ -f "$build_dir/efivars.fd" ] || cp "$fw_vars" "$build_dir/efivars.fd"
    fw_args+=(-drive "if=pflash,format=raw,file=$build_dir/efivars.fd")
fi

# --- disk ---------------------------------------------------------------------
disk=$image_abs
fmt=raw
if [ "${JINOS_PERSIST:-0}" != 1 ]; then
    disk=$build_dir/run.qcow2
    fmt=qcow2
    rm -f "$disk"
    qemu-img create -q -f qcow2 -b "$image_abs" -F raw "$disk"
fi

# --- display / serial ---------------------------------------------------------
io_args=(-device virtio-vga)
case "${JINOS_DISPLAY:-gui}" in
    gui)  ;;
    none) io_args+=(-display none) ;;
    *)    echo "run-qemu: JINOS_DISPLAY must be gui or none" >&2; exit 1 ;;
esac
case "${JINOS_SERIAL:-stdio}" in
    stdio)  io_args+=(-serial mon:stdio) ;;
    file:*) io_args+=(-serial "$JINOS_SERIAL" -monitor none) ;;
    *)      echo "run-qemu: JINOS_SERIAL must be stdio or file:<path>" >&2; exit 1 ;;
esac

echo "run-qemu: $image ($accel, $fmt); ssh -p ${JINOS_SSH_PORT:-2222} jin@localhost" >&2

# shellcheck disable=SC2086  # QEMU_EXTRA is intentionally word-split
exec "$qemu" \
    -name jinos \
    -machine "q35,accel=$accel" -cpu "$cpu" \
    -smp "${JINOS_CPUS:-2}" -m "${JINOS_MEM:-2048}" \
    "${fw_args[@]}" \
    -drive "if=none,id=disk0,format=$fmt,file=$disk" \
    -device virtio-blk-pci,drive=disk0,bootindex=0 \
    -netdev "user,id=net0,hostfwd=tcp::${JINOS_SSH_PORT:-2222}-:22" \
    -device virtio-net-pci,netdev=net0 \
    -device virtio-rng-pci \
    "${io_args[@]}" \
    ${QEMU_EXTRA:-}
