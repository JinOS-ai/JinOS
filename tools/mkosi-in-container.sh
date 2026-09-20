#!/usr/bin/env bash
# Run mkosi inside the Debian 13 builder container (tools/builder/Dockerfile).
# All arguments are passed to mkosi; the repository is mounted at /src.
#
# Needs docker or podman. --privileged is required: mkosi creates mount
# namespaces and bind mounts for its build sandbox. The container is always
# linux/amd64 so the x86-64 image's package scripts run natively (on Apple
# Silicon this goes through Docker Desktop's Rosetta/QEMU emulation).
set -euo pipefail

repo=$(cd "$(dirname "$0")/.." && pwd)
runtime=${CONTAINER_RUNTIME:-}
if [ -z "$runtime" ]; then
    for candidate in docker podman; do
        if command -v "$candidate" >/dev/null 2>&1; then runtime=$candidate; break; fi
    done
fi
if [ -z "$runtime" ]; then
    echo "mkosi-in-container: docker or podman is required (or install mkosi natively on Linux and run 'make image MKOSI=native')" >&2
    exit 1
fi

tag=jinos-builder:trixie
"$runtime" build --platform linux/amd64 -q -t "$tag" "$repo/tools/builder" >/dev/null

# Build as root inside the container, then hand the outputs back to the host user.
exec "$runtime" run --rm --privileged --platform linux/amd64 \
    -v "$repo:/src" -w /src \
    -e "HOST_UID=$(id -u)" -e "HOST_GID=$(id -g)" \
    "$tag" \
    sh -c 'mkosi "$@"; rc=$?; [ -d /src/build ] && chown -R "$HOST_UID:$HOST_GID" /src/build; exit $rc' -- "$@"
