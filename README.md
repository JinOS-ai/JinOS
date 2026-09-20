# jinOs@ai

*An AI-native Linux distribution for laptops, tablets and (eventually) phones.*

jinOs@ai is a Linux-based operating system whose defining feature is an **assistant built into the system layer** — not an app, but a daemon with a permissioned tool interface to the OS and to every app on it. The rest of the stack is deliberately conventional: a mainline Linux kernel, a Debian base, a Wayland compositor and a Flutter shell.

> **Status: pre-alpha, Phase 0 (foundations) in progress.** A minimal Debian-based image builds and boots to a login prompt in QEMU; nothing graphical yet. See [ROADMAP.md](ROADMAP.md) for what gets built in what order.

## What it is

- **Linux kernel, custom userspace.** Mainline LTS kernel and a Debian 13 base, built into an immutable, A/B-updatable image. Effort goes into the layers above the kernel, not into rewriting it.
- **Wayland + Flutter.** A Rust compositor (`jincomp`, on Smithay) and a Flutter system shell (`jinshell`): launcher, windows, settings, notifications, assistant panel.
- **AI assistant as a system service.** `jind` runs local models (llama.cpp, whisper.cpp, Piper) with optional remote fallback, and exposes system and app capabilities to the model through a permissioned tool registry.
- **Android apps** via [Waydroid](https://waydro.id/), surfaced in the shell as first-class launchables.
- **x86_64 first, ARM64 second.** Everything runs in QEMU with one command before it touches real hardware.

## Architecture at a glance

```
┌─────────────────────────────────────────────────────────────────┐
│  jinshell (Flutter)          Android apps (Waydroid)   Native   │
│  launcher · windows · settings · assistant panel       Wayland  │
├─────────────────────────────────────────────────────────────────┤
│  jind — assistant daemon (Rust)                                 │
│  local LLM / STT / TTS · remote fallback · tool registry · D-Bus│
├─────────────────────────────────────────────────────────────────┤
│  jincomp — Wayland compositor (Rust / Smithay)                  │
├─────────────────────────────────────────────────────────────────┤
│  Debian 13 base · systemd · PipeWire · NetworkManager           │
├─────────────────────────────────────────────────────────────────┤
│  Linux kernel (LTS, jinOs config)                               │
├─────────────────────────────────────────────────────────────────┤
│  x86_64 (QEMU → laptops)  ·  ARM64 (SBC → tablets/phones)       │
└─────────────────────────────────────────────────────────────────┘
```

Full detail in [docs/architecture.md](docs/architecture.md).

## Roadmap

| Phase | Weeks | Milestone (what you can demo) |
|---|---|---|
| 0 Foundations | 1–2 | `make run` boots a jinOs image to a login prompt in QEMU |
| 1 Graphical base | 3–8 | Boots straight into a Flutter shell |
| 2 Shell & compositor | 9–16 | Launch, manage and switch native Wayland apps from the shell |
| 3 Assistant v1 (text) | 17–24 | Type "open a terminal and dim the screen" — it happens |
| 4 Voice & Android | 25–32 | Say it instead; the app it opens can be an Android app |
| 5 Installer, updates, hardware | 33–40 | Install on a real laptop; A/B OTA update |
| 6 ARM64 | 41+ | Same image on a Raspberry Pi 5, then a Linux phone |

Timeline assumes one full-time developer. Details, exit criteria and risks per phase: [ROADMAP.md](ROADMAP.md).

## Documentation

- [ROADMAP.md](ROADMAP.md) — phases, milestones, exit criteria
- [docs/architecture.md](docs/architecture.md) — layers, components, boot flow, repo layout
- [docs/decisions.md](docs/decisions.md) — architecture decision records (why Linux, why Flutter, why Waydroid…)
- [docs/dev-environment.md](docs/dev-environment.md) — host setup for building and running in QEMU
- `docs/components/` — design notes per component: [base image](docs/components/base-image.md), [compositor](docs/components/compositor.md), [shell](docs/components/shell.md), [assistant](docs/components/assistant.md), [Android](docs/components/android.md), [updates & installer](docs/components/updates.md)

## Getting started

```bash
make image   # build build/jinos.raw (mkosi, natively on Linux or in a Debian 13 container)
make run     # boot it in QEMU; log in as jin / jinos
```

You need Docker or Podman (or mkosi on a Linux host) to build, and QEMU to run. Details, knobs and platform notes: [docs/dev-environment.md](docs/dev-environment.md).

## Out of scope (for now)

- A custom kernel — see [ADR-001](docs/decisions.md#adr-001--linux-kernel-not-a-custom-kernel).
- Qt. One UI toolkit (Flutter) — see [ADR-004](docs/decisions.md#adr-004--flutter-for-the-shell-qt-dropped).
- Embedded/IoT targets and WebOS-style environments.
- Phone telephony/modem stacks before Phase 6.

## Contributing

Solo project for now, but issues and PRs are welcome — especially on the compositor (Rust/Smithay), the shell (Flutter) and the assistant (Rust). Read the ADRs first; they explain the choices you'll otherwise want to question.

## License

[MIT](./LICENSE)
