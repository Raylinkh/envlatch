---
name: envlatch
description: Run local commands with API keys stored in EnvLatch instead of copying credentials between .env files or shell profiles. Use when an agent, CLI, script, SDK, test, or build needs a saved credential environment variable on macOS.
---

# EnvLatch

Use one wrapper contract for every provider and tool. A named launch profile selects the exact saved keys and per-key endpoint bindings the target needs:

```sh
envlatch run -- <program> [args...]
envlatch run --using <profile-name> -- <program> [args...]
```

## Workflow

1. Run `envlatch doctor`.
2. Optionally register this agent or host for setup status: choose a short descriptive name and run `envlatch pair "<agent-or-host-name>"`. Pairing is not authorization and is not restricted to a built-in host list.
3. Run `envlatch help` before first use so the installed CLI remains the source of truth.
4. Run `envlatch profiles`. This returns only non-secret launch-profile membership, provider, saved key name, API contract, and base URL metadata.
5. Preserve the user's exact program and arguments and run `envlatch run --using <profile-name> -- <program> [args...]`. EnvLatch validates the complete profile before reading secrets, then loads only its selected Keychain items and applies each key's client binding.
6. If no matching launch profile exists, ask the user to create one in the EnvLatch GUI. Do not silently fall back to broad `envlatch run --`; it exposes every saved key and is only for explicit user-authorized compatibility use.
7. If the command is already running without its key or endpoint profile, restart it through the wrapper; environment variables cannot be added safely to an existing process.

## Secret handling

- Never print, echo, log, inspect, or ask EnvLatch to reveal a stored value.
- Treat profile metadata as routing configuration, never as a place to store a key. Secret values belong only in the EnvLatch GUI and macOS Keychain.
- Never dump the launched environment or write a stored value to `.env`, a shell profile, a command argument, a prompt, or a repository file.
- Never replace the wrapper with `eval`, command substitution, or a shell export pipeline.
- Treat the launched program and every descendant as able to read every value selected by that launch profile.
- A profiled launch exposes only its selected Keychain items under their saved names and configured client bindings. A broad unprofiled launch exposes every saved key.
- Ask the user to add or rotate a missing value in the EnvLatch GUI; do not solicit the plaintext in chat.
