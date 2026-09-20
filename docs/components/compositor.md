# jincomp — compositor

**Directory:** `compositor/` · **Language:** Rust (Smithay) · **Phase:** 2 (interim `cage` in Phase 1)

## Purpose

A Wayland compositor whose only job is to serve `jinshell` and the apps it launches, on laptops, tablets and phones, with the minimum feature set that makes the shell possible.

## Scope

In scope for Phase 2:
- Wayland core, xdg-shell (toplevel + popup), wlr-layer-shell (shell panel/background/overlays), xdg-decoration (server-side only), wp-viewporter, presentation-time.
- Single output; DRM/KMS backend (udev + libinput) and a winit backend for running nested during development.
- Input: keyboard (xkb), pointer, touch; basic gestures forwarded to the shell.
- Window management: stacking, focus, maximise, fullscreen, a few keyboard shortcuts; a "mobile" mode where every toplevel is maximised.
- Shell protocol: private interface for window list / focus / activate / close, output info and launch requests (Wayland protocol vs D-Bus is an open question in the roadmap).
- Screenshot/screencast for the assistant later, via xdg-desktop-portal.

Out of scope until after Phase 5: multi-monitor, tiling, animations, XWayland (unless forced), fractional-scaling polish, HDR.

## Design notes

- Start from Smithay's `smallvil` example and grow; keep `anvil` as a reference for feature implementations.
- The shell is identified by app-id (`ai.jinos.shell`) and is the only client allowed layer-shell surfaces on the `top`/`overlay` layers.
- Render with Smithay's GLES renderer; llvmpipe fallback in QEMU.
- Crash policy: `jincomp` is restarted by systemd; clients die with it in v0.x. Session persistence is a later concern.

## Testing

- Nested (winit) mode for day-to-day development on the host.
- A 1-hour soak script that opens/closes `foot` windows, run in CI in QEMU with llvmpipe.
- `wayland-info` smoke checks for advertised globals.
