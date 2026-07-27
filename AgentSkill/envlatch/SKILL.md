---
name: envlatch
description: Run local commands with API keys stored in EnvLatch instead of copying credentials between .env files or shell profiles. Use when an agent, CLI, script, SDK, test, or build needs a saved credential environment variable on macOS.
---

# EnvLatch

Use one wrapper contract for every provider and tool. A saved key works directly, repeated `--using` flags select several saved keys once, and an optional key group saves a reusable combination:

```sh
envlatch run --using <saved-key-name> -- <program> [args...]
envlatch run --using <saved-key-name> --using <saved-key-name> -- <program> [args...]
envlatch run --using <group-name> -- <program> [args...]
envlatch groups create "<group-name>" --using <saved-key-name> --using <saved-key-name>
```

## Workflow

1. Run `envlatch doctor`.
2. Optionally register this agent or host for setup status: choose a short descriptive name and run `envlatch pair "<agent-or-host-name>"`. Pairing is not authorization and is not restricted to a built-in host list.
3. Run `envlatch help` before first use so the installed CLI remains the source of truth.
4. Run `envlatch list`. This returns saved environment-variable names only. Use the exact saved key name directly when the command needs one key.
5. If the command needs several saved keys once, repeat `--using` with each exact saved key name. Repeated selectors accept saved keys only; a named key group must be used by itself.
6. If the same combination will be reused, run `envlatch groups create "<group-name>" --using <saved-key> --using <saved-key>`. This stores names only and never reads values. Run `envlatch groups` to inspect non-secret membership and per-key endpoint metadata.
7. Preserve the user's exact program and arguments. EnvLatch validates the complete selection before reading secrets, then loads only its selected Keychain items and applies each key's client binding.
8. If a required saved key is missing, ask the user to add or rotate it in the EnvLatch GUI. Do not silently fall back to broad `envlatch run --`; it exposes every saved key and is only for explicit user-authorized compatibility use.
9. If the command is already running without its key or endpoint metadata, restart it through the wrapper; environment variables cannot be added safely to an existing process.

## Secret handling

- Never print, echo, log, inspect, or ask EnvLatch to reveal a stored value.
- Treat endpoint and key-group metadata as routing configuration, never as a place to store a key. `groups create` accepts saved key names only. Secret values belong only in the EnvLatch GUI and macOS Keychain.
- Never dump the launched environment or write a stored value to `.env`, a shell profile, a command argument, a prompt, or a repository file.
- Never replace the wrapper with `eval`, command substitution, or a shell export pipeline.
- Treat the launched program and every descendant as able to read every value selected by that key or key group.
- A `--using` launch exposes only its complete validated selection under saved names and configured client bindings. Repeated saved-key selections are validated together before any value is read. A broad launch without `--using` exposes every saved key.
- Ask the user to add or rotate a missing value in the EnvLatch GUI; do not solicit the plaintext in chat.
