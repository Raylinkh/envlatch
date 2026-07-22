---
name: agent-keyring
description: Run local commands with API keys stored in AgentKeyring instead of copying credentials between .env files or shell profiles. Use when an agent, CLI, script, SDK, test, or build needs a saved credential environment variable on macOS.
---

# AgentKeyring

Use one wrapper contract for every provider and tool. Pair the current agent or host once, then select endpoint metadata only when the target needs it:

```sh
agent-keyring run -- <program> [args...]
agent-keyring run --using <profile-name> -- <program> [args...]
```

## Workflow

1. Run `agent-keyring doctor`.
2. If this agent or host is not named in the receipt, choose a short descriptive name and run `agent-keyring pair "<agent-or-host-name>"`. Pairing is not restricted to a built-in host list.
3. Run `agent-keyring help` before first use so the installed CLI remains the source of truth.
4. Run `agent-keyring profiles`. This returns only non-secret provider name, saved key name, API contract, and base URL metadata.
5. When a matching profile exists, preserve the user's exact program and arguments and run `agent-keyring run --using <profile-name> -- <program> [args...]`. AgentKeyring loads only that profile's Keychain item and derives its configured client environment binding.
6. Otherwise run `agent-keyring list` to confirm the needed saved environment-variable name, then use `agent-keyring run -- <program> [args...]`.
7. If the command is already running without its key or endpoint profile, restart it through the wrapper; environment variables cannot be added safely to an existing process.

## Secret handling

- Never print, echo, log, inspect, or ask AgentKeyring to reveal a stored value.
- Treat profile metadata as routing configuration, never as a place to store a key. Secret values belong only in the AgentKeyring GUI and macOS Keychain.
- Never dump the launched environment or write a stored value to `.env`, a shell profile, a command argument, a prompt, or a repository file.
- Never replace the wrapper with `eval`, command substitution, or a shell export pipeline.
- Treat the launched program and every descendant as able to read all saved AgentKeyring values.
- A profiled launch exposes only its referenced Keychain item under the saved name and configured client binding. An unprofiled launch exposes every saved key.
- Ask the user to add or rotate a missing value in the AgentKeyring GUI; do not solicit the plaintext in chat.
