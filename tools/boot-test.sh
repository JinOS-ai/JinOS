#!/usr/bin/env bash
# Phase 0 exit criterion, automated: boot the image headless and wait for a
# login prompt on the serial console. Exit 0 on success.
#
#   BOOT_TIMEOUT  seconds to wait (default 600; TCG on Apple Silicon is slow)
#   BOOT_LOG      serial log path (default build/boot-test.log)
set -euo pipefail

image=${1:-build/jinos.raw}
timeout=${BOOT_TIMEOUT:-600}
log=${BOOT_LOG:-build/boot-test.log}
here=$(cd "$(dirname "$0")" && pwd)

rm -f "$log"
JINOS_DISPLAY=none JINOS_SERIAL="file:$log" "$here/run-qemu.sh" "$image" &
qemu_pid=$!
trap 'kill "$qemu_pid" 2>/dev/null || true' EXIT

elapsed=0
while [ "$elapsed" -lt "$timeout" ]; do
    if grep -q 'login:' "$log" 2>/dev/null; then
        echo "boot-test: login prompt after ${elapsed}s"
        grep -m1 'login:' "$log"
        exit 0
    fi
    if ! kill -0 "$qemu_pid" 2>/dev/null; then
        echo "boot-test: QEMU exited before a login prompt appeared" >&2
        [ -f "$log" ] && tail -n 60 "$log" >&2
        exit 1
    fi
    sleep 5
    elapsed=$((elapsed + 5))
done

echo "boot-test: no login prompt after ${timeout}s" >&2
[ -f "$log" ] && tail -n 60 "$log" >&2
exit 1
