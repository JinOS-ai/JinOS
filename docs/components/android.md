# Android compatibility

**Mechanism:** Waydroid · **Phase:** 4 · **Where:** `base/` (packages, units, config) and `shell/launcher`

## How it works

Waydroid runs a LineageOS-based Android system image in an LXC container sharing the jinOs kernel. Android surfaces are rendered through Wayland, so `jincomp` sees each Android app window as an ordinary client (Waydroid multi-window mode). Requirements: `binder_linux`/binderfs in the kernel (enabled from Phase 1, [ADR-005](../decisions.md#adr-005--waydroid-for-android-apps)) and a GPU path.

## Integration

- **Image:** `waydroid` package; Android system + vendor images downloaded at image build time or on first boot into the data partition (they are large and not part of the A/B root).
- **Service:** `waydroid-container.service` started lazily on first Android app launch, not at boot.
- **Launcher:** Waydroid generates `.desktop` entries for installed Android apps; `jinshell`'s launcher reads them like any other and tags them "Android".
- **Assistant:** `launch_android_app` tool; nothing else in `jind` knows about Android.
- **Windows:** `jincomp` applies the same rules as for native clients; in mobile layout, Android apps are fullscreen like everything else.

## Rendering in QEMU

Without virgl, Waydroid must run with software rendering: `ro.hardware.gralloc=default` and `ro.hardware.egl=swiftshader` in Waydroid's properties. Slow, but sufficient to prove integration; performance is evaluated on the Phase 5 reference laptop (Intel/AMD Mesa).

## Not included

- Google Play services / GAPPS. Users may install alternative stores (F-Droid is the demo app).
- Android app access to jinOs tools or the assistant. Android apps are sandboxed as Waydroid sandboxes them.
- ARM-only APKs on x86_64 (needs libhoudini/libndk translation; revisit if demanded).
