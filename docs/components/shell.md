# jinshell — system shell

**Directory:** `shell/` · **Language:** Dart / Flutter · **Phase:** 1 (hello shell), 2 (usable), grows every phase

## Purpose

Everything the user sees that is not an application: background, launcher, window switcher, quick settings, notifications, assistant panel and (Phase 5) the installer.

## Structure

One Flutter app, app-id `ai.jinos.shell`, whose window the compositor places as a layer-shell surface covering the output. The shell draws its own panel, drawer and overlays. Apps render in the compositor's normal layer above the shell's background surface and below its overlay surfaces.

Modules (Dart packages inside `shell/`):

| Package | Role | Phase |
|---|---|---|
| `shell_core` | compositor protocol client; D-Bus clients (NetworkManager, logind, UPower, wireplumber); settings store | 1–2 |
| `launcher` | `.desktop` parsing, search, favourites, Android app entries | 2, 4 |
| `panel` | clock, status icons, quick settings, window switcher | 2 |
| `notifications` | `org.freedesktop.Notifications` server; toasts + centre | 2 |
| `assistant_ui` | chat panel, streaming, action cards with approve/deny, voice indicator | 3–4 |
| `settings` | Wi-Fi, display, sound, assistant (model choice, remote endpoint, tool policies), updates | 2–5 |
| `installer` | live-USB install flow | 5 |

## Layout modes

Two layouts from the same widgets, chosen by output size and input capabilities: **desktop** (panel, floating windows, pointer) and **mobile** (bottom navigation, one app fullscreen, touch). Designed in Phase 2, exercised on real touchscreens in Phase 6.

## Integration points

- Compositor: shell protocol (window list, focus, launch).
- Assistant: D-Bus `ai.jinos.Assistant` (send, stream, tools, approvals).
- System: NetworkManager, logind, UPower, wireplumber, xdg-desktop-portal, systemd-sysupdate (Phase 5).

## Build & deploy

Built on the host with the Flutter SDK, bundled as a self-contained Linux app, installed under `/usr/lib/jinshell/`. `make deploy` copies the bundle into the running VM and restarts `jincomp` (which respawns the shell).
