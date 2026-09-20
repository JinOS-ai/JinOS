# jinOs@ai Roadmap

The working plan for getting from an empty repository to an installable, AI-native Linux OS. It assumes **one full-time developer**; weeks are sequencing estimates, not commitments. Each phase ends with something that can be demoed in QEMU (or, from Phase 5, on hardware).

## Principles

1. **Demo every phase.** A phase is done when its milestone runs from `make run`, not when the code exists.
2. **Borrow before building.** Use existing components (cage, Waydroid, llama.cpp, mkosi) wherever the component is not what makes jinOs different. Build only the shell, the assistant and — later — the compositor.
3. **Two languages.** Rust for anything that runs as a system service; Dart/Flutter for anything with pixels. Shell/Python only for build glue. No C++ or Go unless a dependency forces it.
4. **QEMU is the primary target until Phase 5.** If it doesn't run in QEMU, it doesn't run.
5. **Immutable base, A/B updates.** The root filesystem is an image, not a mutable install. Decided now even though the updater arrives in Phase 5, because it constrains how everything else is packaged.
6. **The assistant is a system layer, not an app.** Every capability it gains goes through the tool registry with a permission class, from the first prototype onward.

## Phase overview

| Phase | Weeks | Goal | Milestone |
|---|---|---|---|
| 0 | 1–2 | Foundations | M0 — `make run` boots to a login prompt in QEMU |
| 1 | 3–8 | Graphical base | M1 — boots directly into a Flutter shell |
| 2 | 9–16 | Shell & compositor | M2 — launch and manage native Wayland apps |
| 3 | 17–24 | Assistant v1 (text) | M3 — typed commands control the system |
| 4 | 25–32 | Voice & Android | M4 — voice command launches an Android app |
| 5 | 33–40 | Installer, updates, hardware | M5 — installed on a laptop; A/B OTA update works |
| 6 | 41+ | ARM64 | M6 — same image boots on Raspberry Pi 5; phone bring-up begins |

---

## Phase 0 — Foundations (weeks 1–2)

**Goal:** a reproducible build that produces a bootable x86_64 image, and a one-command QEMU run.

**Deliverables**
- Repository layout per [docs/architecture.md](docs/architecture.md#repository-layout).
- `base/`: mkosi configuration producing a Debian 13 (trixie) image with systemd, systemd-boot, a serial console and an SSH server (dev profile).
- Kernel: Debian's LTS kernel package to start; custom config deferred to Phase 1.
- `tools/run-qemu.sh` with virtio-gpu, virtio-net (user-mode with SSH port forward), virtio-blk.
- `Makefile` targets: `image`, `run`, `ssh`, `clean`.
- CI (GitHub Actions) that builds the image on every push.

**Exit criteria**
- Fresh clone → `make image && make run` → login prompt on the QEMU serial console and in the graphical window.
- CI green.

**Risks**
- mkosi behaviour differs between host distributions. Mitigation: pin the mkosi version; document the host in [docs/dev-environment.md](docs/dev-environment.md); build inside a container if needed.

## Phase 1 — Graphical base (weeks 3–8)

**Goal:** the image boots into a fullscreen Flutter application with no login step.

**Deliverables**
- Kernel config with DRM/KMS, virtio-gpu, and the Waydroid prerequisites (`binder_linux`, binderfs) enabled now so Phase 4 needs no kernel change.
- `cage` (wlroots kiosk compositor) as the interim compositor, started by a systemd unit as user `jin`, with seatd for seat management.
- `shell/`: a Flutter Linux app ("hello shell") — clock, placeholder launcher, quit-to-console button. Standard GTK embedder.
- Flutter build integrated into `make image` (shell built on the host, installed into the image).
- PipeWire and NetworkManager in the image, not yet surfaced in the UI.

**Exit criteria**
- `make run` → jinOs boots to the Flutter shell in under 20 s in QEMU with no interaction.
- Shell rebuild-and-redeploy loop under 2 minutes (`make shell && make deploy` over SSH, no full image rebuild).

**Risks**
- Flutter's GTK embedder on Wayland without a desktop session may need environment tweaks (`GDK_BACKEND=wayland`, `XDG_RUNTIME_DIR`). Fallback: [flutter-elinux](https://github.com/sony/flutter-elinux) Wayland backend.
- virtio-gpu 3D acceleration in QEMU varies by host. Fallback: llvmpipe software rendering; keep the shell light.

## Phase 2 — Shell & compositor (weeks 9–16)

**Goal:** a usable desktop: launch native Wayland apps, switch between them, basic system controls.

**Deliverables**
- `compositor/`: `jincomp`, a Rust compositor on Smithay. Scope for this phase: xdg-shell, wlr-layer-shell (so the Flutter shell can be a panel/background), a single output, keyboard/pointer/touch input, simple stacking window management. **No** tiling, animations or multi-monitor yet.
- Shell ↔ compositor protocol: a small private Wayland protocol or D-Bus interface for window list, focus and launch requests. Decision recorded as an ADR when made.
- `jinshell` features: app launcher (reads `.desktop` files), window switcher, quick settings (brightness, volume, Wi-Fi via NetworkManager D-Bus, power), notifications (implements `org.freedesktop.Notifications`).
- A terminal (foot) and a browser in the image as the first "apps".
- Replace `cage` with `jincomp` once it runs the shell + one app reliably; keep `cage` selectable via kernel cmdline for debugging.

**Exit criteria**
- Open terminal and browser from the launcher, switch between them, close them, adjust volume/brightness, receive a notification — all from `make run`.
- `jincomp` survives a 1-hour soak of opening/closing windows without leaking or crashing.

**Risks**
- Smithay is the largest single piece of new code in the project. Mitigation: start from the Smithay `smallvil`/`anvil` examples; keep `cage` as the fallback all through Phase 2 so shell work is never blocked.
- Flutter as a layer-shell client: the GTK embedder doesn't speak layer-shell natively. Options: `gtk-layer-shell`, or `jincomp` treating a specific app-id as the shell. The latter is simpler and is the default plan.

## Phase 3 — Assistant v1, text (weeks 17–24)

**Goal:** a text assistant that can actually do things on the system, with a permission model from day one.

**Deliverables**
- `assistant/`: `jind`, a Rust daemon:
  - **Model backend** trait with two implementations: local (llama.cpp via Rust bindings, a ~3B-parameter instruct model in GGUF) and remote (OpenAI-compatible chat-completions API with tool calling; endpoint and key user-configured).
  - **Tool registry**: tools declared with a JSON schema, a description and a permission class (`read`, `act`, `dangerous`). Phase 3 tools: launch app, list/focus/close windows, set brightness/volume, Wi-Fi status/connect, open URL, find files by name, read clipboard, system status (time, battery, notifications), power off/reboot.
  - **Permission model**: `read` tools run silently; `act` tools run with a visible toast; `dangerous` tools require on-screen confirmation. Per-tool `always`/`ask`/`never` policy persisted.
  - **D-Bus API** (`ai.jinos.Assistant`) for the shell: send message, stream response, list tools, approve/deny pending action, history.
- Shell: assistant panel (slide-over), streaming responses, inline action cards with approve/deny.
- Routing policy: local model by default; remote when the user opts in or when the local model fails to produce a valid tool call (rule recorded as an ADR).

**Exit criteria**
- "open a terminal and turn the brightness down" performs both actions in QEMU on the local model.
- A `dangerous` tool (e.g. `power_off`) is never executed without on-screen confirmation.
- Remote backend passes the same test suite as the local one.

**Risks**
- Small local models are unreliable at tool calling. Mitigation: grammar-constrained decoding in llama.cpp for the tool-call format; keep the tool set small and well-described; fall back to remote for multi-step plans.
- Local inference in QEMU (no GPU) is slow. Acceptable in Phase 3 for correctness testing; performance is measured on hardware in Phase 5.

## Phase 4 — Voice & Android (weeks 25–32)

**Goal:** talk to it; run Android apps from the same launcher.

**Deliverables — voice**
- STT: whisper.cpp (base/small model), streaming from PipeWire.
- Wake word: openWakeWord (ONNX Runtime), running continuously at low cost; push-to-talk as the alternative.
- TTS: Piper, with a jinOs default voice.
- Shell: listening indicator, live transcript, spoken-responses toggle.

**Deliverables — Android**
- Waydroid installed in the image, with a pre-initialised LineageOS-based system image (no GAPPS by default).
- Android apps appear in the launcher as `.desktop` entries; `jincomp` handles Waydroid's windows like any other Wayland client (multi-window mode).
- Assistant tool: launch Android app by name.

**Exit criteria**
- "Hey Jin, open F-Droid" spoken into the QEMU host mic launches the app inside Waydroid.
- Wake-word false-positive rate acceptable over a 1-hour idle test with background audio.

**Risks**
- Waydroid in QEMU needs either virgl or software rendering (`ro.hardware.gralloc=default`, `ro.hardware.egl=swiftshader`) — slow but sufficient to prove integration.
- Audio latency through PipeWire in a VM. Acceptable for development.

## Phase 5 — Installer, updates, hardware (weeks 33–40)

**Goal:** jinOs on a real laptop, updating itself.

**Deliverables**
- A/B partition layout with systemd-boot and `systemd-sysupdate` (or RAUC if sysupdate proves insufficient); signed images; automatic rollback on failed boot via boot counting.
- Installer: a live-USB image running `jinshell` in "install" mode — pick disk, confirm, write, reboot. Whole-disk only in this phase.
- Persistent user data on a separate partition (`/home`, `/var`, `/etc/jinos`), unaffected by updates.
- Hardware bring-up on one reference laptop (a well-supported Intel/AMD model with mainline Wi-Fi): touchpad gestures, backlight, suspend/resume, Wi-Fi, audio.
- Local model performance measured on the reference laptop; model size and quantisation chosen accordingly.

**Exit criteria**
- Install from USB on the reference laptop in under 10 minutes; boot to shell; assistant works offline.
- Publish an update; device fetches and applies it and reboots into the new slot; a deliberately broken update rolls back.

**Risks**
- Firmware/driver gaps on the chosen laptop. Mitigation: pick hardware from the "works out of the box" tier on linux-hardware.org.
- Secure Boot. Out of scope for v0.1; document how to disable it.

## Phase 6 — ARM64 (weeks 41+)

**Goal:** the same image pipeline produces ARM64 images; first a single-board computer, then a phone.

**Deliverables**
- mkosi cross-build for ARM64; Raspberry Pi 5 as the first target (mainline kernel support, well-understood boot).
- Touch-first shell layout mode (designed in Phase 2, exercised here on a touchscreen).
- Phone bring-up on a device with mainline support (e.g. a postmarketOS "community"-tier device). Telephony is a stretch goal and depends on ModemManager support for the chosen device.

**Exit criteria**
- `make image ARCH=arm64` → boots to shell on a Pi 5 with a touchscreen; assistant runs locally (small model).

---

## Deferred / out of scope

| Item | Why | Revisit |
|---|---|---|
| Custom kernel (C + Rust) | Years of work before parity with Linux; does not serve the AI-native goal | Only as a separate research project |
| Qt | Two toolkits doubles UI effort | No |
| Multi-monitor, tiling, animations in `jincomp` | Not needed for the milestone demos | After Phase 5 |
| App store / package manager UI | Flatpak is the likely answer; needs the immutable-base work from Phase 5 first | Phase 5+ |
| Telephony | Device-specific and driver-bound | Phase 6 stretch |
| IoT / embedded targets, WebOS-style runtimes | Different product | No |
| Secure Boot signing | Requires key management and shim work | Post-v0.1 |

## Open questions (to be resolved as ADRs)

- Shell ↔ compositor IPC: custom Wayland protocol vs D-Bus vs both.
- Flatpak as the app distribution mechanism, and how the assistant's tool registry interacts with sandboxed apps (xdg-desktop-portal is the likely bridge).
- Remote model provider: OpenAI-compatible only, or also native support for other vendor APIs.
- Whether apps can register their own tools with `jind` (an MCP-style server registry), and what the permission UX for that looks like.
