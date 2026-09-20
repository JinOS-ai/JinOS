# Architecture

jinOs@ai is a Linux distribution with a custom userspace. The kernel and base system are conventional; the three components that make it jinOs are the **compositor** (`jincomp`), the **shell** (`jinshell`) and the **assistant daemon** (`jind`).

## Layers

```
┌─────────────────────────────────────────────────────────────────────┐
│ Applications                                                        │
│   Native Wayland apps · Android apps (Waydroid) · Flatpaks (later)  │
├─────────────────────────────────────────────────────────────────────┤
│ jinshell (Flutter / Dart)                                           │
│   launcher · window switcher · quick settings · notifications ·     │
│   assistant panel · installer mode                                  │
├──────────────────────────────┬──────────────────────────────────────┤
│ jind (Rust)                  │ jincomp (Rust / Smithay)             │
│   model backends             │   xdg-shell · layer-shell · input ·  │
│   (local / remote)           │   output · window management ·       │
│   tool registry + permissions│   shell protocol                     │
│   STT / TTS / wake word      │                                      │
│   D-Bus API                  │                                      │
├──────────────────────────────┴──────────────────────────────────────┤
│ Base system (Debian 13)                                             │
│   systemd · systemd-boot · PipeWire · NetworkManager · seatd ·      │
│   Waydroid · systemd-sysupdate (A/B) · xdg-desktop-portal           │
├─────────────────────────────────────────────────────────────────────┤
│ Linux kernel (LTS, jinOs config: DRM/KMS, virtio, binder)           │
├─────────────────────────────────────────────────────────────────────┤
│ Hardware: x86_64 (QEMU, laptops) · ARM64 (Raspberry Pi 5, phones)   │
└─────────────────────────────────────────────────────────────────────┘
```

## Components

| Component | Dir | Language | Role | Phase |
|---|---|---|---|---|
| Base image | `base/` | mkosi config, shell | Builds the bootable Debian-based image; kernel config; systemd units | 0 |
| `jinshell` | `shell/` | Dart / Flutter | Everything the user sees that isn't an app | 1 |
| `jincomp` | `compositor/` | Rust (Smithay) | Wayland compositor; window management; shell integration | 2 |
| `jind` | `assistant/` | Rust | Assistant daemon: models, tools, permissions, voice | 3 |
| Android | `base/` (config) | — | Waydroid integration and launcher entries | 4 |
| Updater / installer | `base/`, `shell/` | mkosi/sysupdate config, Dart | A/B updates, live-USB installer | 5 |
| Tools | `tools/` | shell, Python | QEMU runner, deploy scripts, CI helpers | 0 |

Detailed notes per component live in [`docs/components/`](components/).

## Boot flow

```
firmware → systemd-boot → kernel (+ initrd) → systemd
  → seatd
  → jincomp.service            (user: jin, seat0)
      → jinshell               (layer-shell client, launched by jincomp)
  → jind.service               (system service, D-Bus activated)
  → pipewire / wireplumber     (user services)
  → waydroid-container.service (Phase 4+, started lazily)
```

There is no display manager and no login screen in v0.x: the image has a single user `jin` and the compositor starts directly. Lock/login UI is a shell feature for later.

## How the assistant is integrated

The assistant is a system service, not an application. Three ideas govern it:

1. **Tools, not scripts.** Every capability is a *tool*: a name, a JSON schema for arguments, a description written for the model, and a permission class. `jind` owns the registry. The model never runs shell commands.
2. **Permission classes.** `read` (silent), `act` (visible toast, undoable where possible), `dangerous` (explicit on-screen confirmation). The class is set by the tool author, never by the model.
3. **Context is opt-in and visible.** What the model can see (window titles, clipboard, notifications, files) is itself gated by `read` tools, and the conversation shows what was accessed.

```
jinshell ──D-Bus (ai.jinos.Assistant)──▶ jind ──▶ model backend (local llama.cpp | remote API)
    ▲                                     │
    │ confirm / deny                      ▼
    └──────────────────────────── tool registry ──▶ D-Bus calls to jincomp, NetworkManager,
                                                    logind, PipeWire, Waydroid, …
```

Later (open question in the roadmap): apps register their own tools via an MCP-style interface, mediated by xdg-desktop-portal for sandboxed apps.

## Repository layout

```
jinOS/
├── README.md            pitch + pointers
├── ROADMAP.md           phases, milestones, exit criteria
├── Makefile             image / run / ssh / shell / deploy / clean
├── docs/
│   ├── architecture.md
│   ├── decisions.md     ADRs
│   ├── dev-environment.md
│   └── components/      one design note per component
├── base/                mkosi configs, kernel config, systemd units, image overlays
├── compositor/          jincomp (Rust crate)
├── shell/               jinshell (Flutter project)
├── assistant/           jind (Rust crate) + model/config assets
├── tools/               run-qemu.sh, deploy.sh, CI scripts
└── .github/workflows/   image build on every push
```

Rust crates share one Cargo workspace at the repository root once both exist.

## Non-goals

See "Deferred / out of scope" in [ROADMAP.md](../ROADMAP.md#deferred--out-of-scope) and the ADRs in [decisions.md](decisions.md).
