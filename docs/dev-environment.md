# Development environment

How to build a jinOs image and boot it in QEMU. Phase 0 state: this works on
Linux natively or via a container, and on macOS via a container; CI does the
same on every push (`.github/workflows/image.yml`).

## The loop

```bash
make image        # build build/jinos.raw (dev profile)
make run          # boot it in QEMU: graphical window + serial console on this terminal
make run-serial   # serial console only
make ssh          # ssh into the running VM (dev profile: jin / jinos, root / jinos)
make boot-test    # headless boot; passes when a login prompt appears on the serial console
make clean        # remove build/
```

`make run` boots a throwaway qcow2 overlay, so every run starts from the
freshly built image; set `JINOS_PERSIST=1` to boot the image in place. Other
knobs (RAM, CPUs, SSH port, extra QEMU args) are documented at the top of
[`tools/run-qemu.sh`](../tools/run-qemu.sh).

## Building the image

Images are built by [mkosi](https://github.com/systemd/mkosi) 25.3 from
`base/` (see [components/base-image.md](components/base-image.md)). `make
image` picks one of two ways to run it:

| Host | How `make image` runs mkosi | Needs |
|---|---|---|
| Linux with `mkosi` installed (Debian 13: `apt install mkosi`) | natively (`MKOSI=native`) | unprivileged user namespaces, or run as root |
| Anything with Docker or Podman — macOS, other Linux, CI | inside the Debian 13 builder container (`MKOSI=container`, [`tools/builder/Dockerfile`](../tools/builder/Dockerfile)) | `docker` or `podman`; the container runs `--privileged` and as `linux/amd64` |

Either way mkosi uses a pinned Debian 13 tools tree (`ToolsTree=default`), so
the resulting image does not depend on the host's tool versions. The first
build downloads the tools tree and package cache into `build/cache/`
(a few hundred MB); later builds reuse it.

On Apple Silicon the amd64 builder container runs under Docker Desktop's
Rosetta/QEMU emulation. It works; expect the first build to take a while.

## Running the image

`make run` needs `qemu-system-x86_64`, `qemu-img` and UEFI firmware:

- Debian/Ubuntu: `sudo apt install qemu-system-x86 qemu-utils ovmf`
- macOS: `brew install qemu` (ships the edk2 firmware)

Acceleration is picked automatically: KVM on x86_64 Linux (`/dev/kvm` must be
writable), HVF on Intel Macs, otherwise TCG. On Apple Silicon the x86-64 image
runs under TCG — fine for Phase 0's login prompt, slow for anything graphical.

## Host requirements

- ~10 GB free disk for the tools tree, package cache, workspace and image; 8 GB RAM is enough for Phase 0.
- Phase 1 adds the Flutter SDK and Rust toolchain on the host; not needed yet.

## Secrets and models (later phases)

- Remote-model API keys are never committed; `jind` reads them from `/etc/jinos/assistant.toml` on the device.
- Model files are downloaded by `make models` into `assistant/models/` (git-ignored).
