# jind — assistant daemon

**Directory:** `assistant/` · **Language:** Rust · **Phase:** 3 (text), 4 (voice)

## Purpose

The system service that makes jinOs "AI-native": it hosts the model, owns the tool registry and the permission model, and exposes a D-Bus API the shell uses for chat, voice and approvals.

## Architecture

```
                 ┌─────────────────────────────────────────────┐
  D-Bus          │ jind                                        │
 (ai.jinos.      │  ┌───────────┐   ┌─────────────────────┐    │
  Assistant) ◀──▶│  │ session   │──▶│ model backend       │    │
                 │  │ manager   │   │  • local (llama.cpp)│    │
                 │  └─────┬─────┘   │  • remote (OpenAI-  │    │
                 │        │         │    compatible API)  │    │
                 │        ▼         └─────────────────────┘    │
                 │  ┌───────────┐   ┌─────────────────────┐    │
                 │  │ tool      │──▶│ tool impls (D-Bus   │    │
                 │  │ registry +│   │ clients to jincomp, │    │
                 │  │ policies  │   │ NM, logind, …)      │    │
                 │  └───────────┘   └─────────────────────┘    │
                 │  ┌───────────┐  ┌─────────┐  ┌──────────┐   │
                 │  │ wake word │  │ STT     │  │ TTS      │   │
                 │  │ openWake- │  │ whisper │  │ Piper    │   │
                 │  │ Word      │  │ .cpp    │  │          │   │
                 │  └───────────┘  └─────────┘  └──────────┘   │
                 └─────────────────────────────────────────────┘
```

### Model backend

A trait `ModelBackend { fn complete(messages, tools) -> Stream<Event> }` with two implementations:

- **Local** — llama.cpp via Rust bindings; quantised GGUF instruct model; grammar-constrained decoding so tool calls are always well-formed JSON. Default ~3B parameters on x86_64 laptops, ~1–2B on ARM64.
- **Remote** — OpenAI-compatible chat completions with tool calling. Endpoint, model name and key in `/etc/jinos/assistant.toml`. Off by default.

Routing (Phase 3 rule, to be refined): local unless the user selected remote, or the local model fails to produce a valid tool call twice.

### Tool registry

Tools are declared in Rust with a manifest like:

```toml
[[tool]]
name = "launch_app"
description = "Launch an installed application by name or desktop id."
permission = "act"

[tool.parameters.app]
type = "string"
description = "Application name or .desktop id"
```

Permission classes:

| Class | Behaviour |
|---|---|
| `read` | executes silently; result may be shown in the conversation |
| `act` | executes; shell shows a toast naming the action; undo where the tool supports it |
| `dangerous` | shell shows a confirm card; tool runs only after approval; never auto-approved |

Per-tool user policy: `always` / `ask` / `never`, persisted on the data partition. `dangerous` tools cannot be set to `always`.

Phase 3 tool set: `launch_app`, `list_windows`, `focus_window`, `close_window`, `set_brightness`, `set_volume`, `wifi_status`, `wifi_connect` (dangerous), `open_url`, `find_files`, `read_clipboard` (read), `system_status` (time, battery, notifications), `power_off` / `reboot` (dangerous).

Phase 4 additions: `launch_android_app`, `speak`, `start_listening`.

### Context

The model sees nothing by default. Context is fetched through `read` tools the model calls explicitly (e.g. `list_windows`, `read_clipboard`), so the conversation log shows every access. Screen content (via portal screenshot) is a deliberate later addition with its own permission prompt.

### Voice pipeline (Phase 4)

PipeWire capture → openWakeWord (continuous, ONNX Runtime) → on trigger, whisper.cpp streaming STT → text into the session → response → Piper TTS → PipeWire playback. Push-to-talk is a shell action that skips the wake word.

## D-Bus API (sketch)

`ai.jinos.Assistant` on the system bus, policy limited to user `jin`:

- `SendMessage(session, text) → id`; signal `Event(id, kind, payload)` for streamed tokens, tool calls, tool results, approval requests, completion.
- `RespondToApproval(request_id, approved)`.
- `ListTools() → [tool]`; `SetToolPolicy(tool, always|ask|never)`.
- `StartListening()`, `StopListening()`; signal `VoiceState(state, transcript)`.
- `GetHistory(session)`.

## Security notes

- `jind` runs as its own system user with no shell access and cannot run arbitrary commands. Every effect is a tool implementation written in Rust.
- Remote backend traffic is HTTPS only; the key never leaves the device except in the request header to the configured endpoint.
- Tool policies persist per tool on the data partition and are editable in Settings.
