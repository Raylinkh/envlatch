---
name: agent-keyring
description: Run local commands with API keys stored in AgentKeyring instead of copying credentials between .env files or shell profiles. Use when an agent, CLI, script, SDK, test, or build needs a saved credential environment variable on macOS.
---

# AgentKeyring

Use the single wrapper contract for every provider and tool:

```sh
agent-keyring run -- <program> [args...]
```

## Workflow

1. Run `agent-keyring list` to confirm the needed environment-variable name is saved. This command returns names only.
2. Preserve the user's exact program and arguments after `--`.
3. Run the command through AgentKeyring. For example, use `agent-keyring run -- make test`, not a provider-specific integration.
4. If the command is already running without its key, restart it through the wrapper; environment variables cannot be added safely to an existing process.
5. If pairing is incomplete, run `agent-keyring doctor` and follow its `pair_command` receipt.

## Secret handling

- Never print, echo, log, inspect, or ask AgentKeyring to reveal a stored value.
- Never dump the launched environment or write a stored value to `.env`, a shell profile, a command argument, a prompt, or a repository file.
- Never replace the wrapper with `eval`, command substitution, or a shell export pipeline.
- Treat the launched program and every descendant as able to read all saved AgentKeyring values.
- Ask the user to add or rotate a missing value in the AgentKeyring GUI; do not solicit the plaintext in chat.
