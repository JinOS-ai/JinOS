# Architecture Decision Records

Short records of the decisions that shape jinOs@ai. Each states the decision, the reason and what it rules out. Add new ADRs at the bottom; never edit an accepted one — supersede it.

---

## ADR-001 — Linux kernel, not a custom kernel

**Status:** accepted · 2026-09-20

**Decision:** jinOs@ai runs on a mainline Linux LTS kernel with a custom configuration. The original plan for a from-scratch C + Rust kernel is dropped from the project.

**Why:** A custom kernel would consume years before reaching driver, multi-arch and security parity that Linux already has, and none of that work advances what makes jinOs different (the shell and the assistant). Android compatibility (Waydroid) also depends on Linux-specific kernel interfaces (binder).

**Consequences:** No kernel code in this repository beyond configuration and, if ever needed, small patches. Rust systems work goes into userspace daemons. A custom-kernel research effort, if ever wanted, lives in a separate repository.

## ADR-002 — Debian 13 base, built as an immutable image with mkosi

**Status:** accepted · 2026-09-20

**Decision:** The base system is Debian 13 (trixie). Images are built with [mkosi](https://github.com/systemd/mkosi) into a read-only root with A/B partitions; user data lives on a separate partition.

**Why:** Debian packages Waydroid, PipeWire, NetworkManager and every build dependency; mkosi produces bootable, signed, A/B-capable images from distro packages with little custom tooling and integrates with systemd-boot and systemd-sysupdate. Deciding on immutability now avoids re-packaging everything later.

**Consequences:** No `apt install` on a running device; all changes go through image rebuilds. Applications beyond the base set will need Flatpak (or similar) — see roadmap open questions. Until Phase 5 the `dev` profile uses a single read-write root for iteration speed.

**Rejected:** Alpine (musl complicates Flutter and Waydroid), Arch (rolling base hurts reproducibility), Buildroot/Yocto (heavier tooling than a solo project warrants).

## ADR-003 — Wayland; `cage` first, then a Smithay compositor

**Status:** accepted · 2026-09-20

**Decision:** jinOs is Wayland-only. Phase 1 uses `cage` (wlroots kiosk compositor) to run the shell fullscreen. Phase 2 replaces it with `jincomp`, a compositor written in Rust on [Smithay](https://github.com/Smithay/smithay). `cage` remains available as a debug fallback.

**Why:** Owning the compositor is necessary for a shell that is more than a desktop app (layer-shell surfaces, window lists, focus control, touch-first behaviour). Smithay is the mature Rust option (used by cosmic-comp and niri). Starting with `cage` means the shell is never blocked on compositor work.

**Consequences:** X11 apps require XWayland, which `jincomp` will support only if a needed app demands it. Multi-monitor, tiling and animations are explicitly deferred.

**Rejected:** Building on wlroots directly (C; breaks the two-language policy). Forking an existing compositor (harder to bend to shell integration than to build minimal features on Smithay).

## ADR-004 — Flutter for the shell; Qt dropped

**Status:** accepted · 2026-09-20

**Decision:** All system UI is one Flutter application, `jinshell`, using the standard Flutter Linux (GTK) embedder. Qt is removed from the plan.

**Why:** One toolkit, one language for UI. Flutter's rendering model suits a touch-and-pointer shell that must look identical on laptops and tablets. The GTK embedder runs on Wayland today; [flutter-elinux](https://github.com/sony/flutter-elinux) is the fallback if GTK becomes a problem on embedded targets.

**Consequences:** The shell runs as a single privileged Wayland client. `jincomp` identifies it by app-id and grants it layer-shell placement; no separate panel/dock/launcher processes.

## ADR-005 — Waydroid for Android apps

**Status:** accepted · 2026-09-20

**Decision:** Android compatibility is provided by [Waydroid](https://waydro.id/) (LineageOS in an LXC container, rendering through Wayland). The kernel config enables `binder_linux`/binderfs from Phase 1.

**Why:** Waydroid is the only actively maintained, Wayland-native Android container for Linux; it is packaged in Debian; it needs no custom kernel beyond binder. The original Anbox is no longer maintained.

**Consequences:** Android apps are second-class in performance (especially in QEMU without virgl) and GAPPS is not shipped. The launcher and assistant treat Android apps as ordinary launchables; nothing else in the system knows about Android.

## ADR-006 — AI stack: local first, remote fallback, tools with permissions

**Status:** accepted · 2026-09-20

**Decision:**
- LLM: llama.cpp via Rust bindings, GGUF instruct models (~3B parameters on laptops, smaller on ARM64), grammar-constrained tool calls.
- STT: whisper.cpp. TTS: Piper. Wake word: openWakeWord (ONNX Runtime).
- Remote fallback: any OpenAI-compatible chat-completions endpoint with tool calling; user-configured, off by default.
- All system capabilities exposed to the model are tools in `jind`'s registry with a permission class (`read` / `act` / `dangerous`).

**Why:** These are the lightest well-maintained local options that run on CPU. Coqui TTS (in the original plan) is archived; Piper is its practical successor for on-device use. Vosk remains a possible low-power STT alternative but whisper.cpp quality is markedly better. A permissioned tool registry is the only way to give a model system access without turning it into a shell with a chat UI.

**Consequences:** Models ship as separately downloaded assets, not baked into the image. The assistant never executes arbitrary commands; new capabilities require writing a tool.

## ADR-007 — Language policy: Rust and Dart

**Status:** accepted · 2026-09-20

**Decision:** System services in Rust; UI in Dart/Flutter; build and CI glue in shell or Python. C++, Go and other languages are not used for first-party code.

**Why:** The original plan listed C, C++, Go, Python, Rust and Dart. For one developer, each additional language is a tax on tooling, CI and context switching. Rust covers everything from the compositor to D-Bus services (zbus); Dart covers all UI.

**Consequences:** Dependencies in other languages (llama.cpp, whisper.cpp, Waydroid's Python) are consumed as libraries or packages, never modified in-tree.

## ADR-008 — x86_64 in QEMU first; ARM64 in Phase 6

**Status:** accepted · 2026-09-20

**Decision:** The sole target through Phase 4 is x86_64 under QEMU (virtio devices). A reference laptop is added in Phase 5; ARM64 (Raspberry Pi 5, then a phone) in Phase 6.

**Why:** QEMU gives a seconds-long edit/boot loop, free CI and no hardware quirks while the shell and assistant are being designed. The mobile thesis is proven last because it is the most driver-bound and least differentiating part of the work.

**Consequences:** The shell must be designed for touch from Phase 2 even though it is exercised with a mouse until Phase 6. Nothing may depend on x86-only components.
