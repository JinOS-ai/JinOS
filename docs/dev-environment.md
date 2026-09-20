# Development environment

Host requirements for building jinOs@ai images and running them in QEMU. This describes the intended setup; it will be validated in Phase 0.

## Host

- Debian 13 or Ubuntu 24.04+ (x86_64). Other distributions work if mkosi is available, but are not tested.
- KVM enabled (`/dev/kvm` accessible) for usable QEMU speed.
- ~40 GB free disk; 16 GB RAM recommended (Flutter + Rust + image builds).

## Toolchain

| Tool | Used for | Notes |
|---|---|---|
| mkosi | building images | version pinned in `base/mkosi.conf`; needs `systemd-repart` and `mmdebstrap`/`debootstrap` |
| QEMU (`qemu-system-x86_64`) | running images | built with `virtio-gpu-gl` for virgl |
| Rust (stable, via rustup) | `jincomp`, `jind` | target `aarch64-unknown-linux-gnu` added in Phase 6 |
| Flutter SDK (stable) | `jinshell` | `flutter config --enable-linux-desktop` |
| clang, cmake, ninja, pkg-config, GTK 3 dev headers | Flutter Linux build | |
| Python 3 | tooling scripts | |

## Intended workflow

```bash
make image            # build the x86_64 disk image (slow: minutes)
make run              # boot it in QEMU with a graphical window + serial console
make ssh              # ssh into the running VM (user jin)
make shell            # build jinshell only
make deploy           # copy freshly built jinshell / jincomp / jind into the running VM and restart them
```

`make deploy` is the inner loop: the image is rebuilt only when the base system or kernel config changes.

## Secrets and models

- Remote-model API keys are never committed; `jind` reads them from `/etc/jinos/assistant.toml` on the device, which lives on the persistent data partition.
- Model files (GGUF, whisper, Piper voices) are downloaded by `make models` into `assistant/models/` (git-ignored) and copied into the image or the data partition.
