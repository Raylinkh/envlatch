---
name: envlatch
description: Run local commands with API keys stored in EnvLatch instead of copying credentials between .env files or shell profiles. Use when an agent, CLI, script, SDK, test, or build needs a saved credential environment variable on macOS.
metadata:
  version: "2026.10.07.1"
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
2. Treat `saved_key_count` as visible to the current process only. If the user expects saved keys and the count is zero, do not conclude that the vault is empty. When doctor exits nonzero with `keychain_visibility_warning=sandboxed_zero_is_inconclusive`, re-run EnvLatch through the host's normal approval path with macOS Keychain access. Do not ask the user to recreate keys or inspect another store based on a sandboxed zero.
3. Run the eventual `envlatch run ...` command through that same normal Keychain-access path. EnvLatch cannot bypass a host sandbox, and running the child outside the wrapper will not receive the selected variables.
4. Optionally register this agent or host for setup status: choose a short descriptive name and run `envlatch pair "<agent-or-host-name>"`. Pairing is not authorization and is not restricted to a built-in host list.
5. Run `envlatch help` before first use so the installed CLI remains the source of truth.
6. Run `envlatch list`. This returns saved environment-variable names only. Use the exact saved key name directly when the command needs one key.
7. If the command needs several saved keys once, repeat `--using` with each exact saved key name. Repeated selectors accept saved keys only; a named key group must be used by itself.
8. If the same combination will be reused, run `envlatch groups create "<group-name>" --using <saved-key> --using <saved-key>`. This stores names only and never reads values. Run `envlatch groups` to inspect non-secret membership and per-key endpoint metadata.
9. Preserve the user's exact program and arguments. EnvLatch validates the complete selection before reading secrets, then loads only its selected Keychain items and applies each key's client binding.
10. If a required saved key is missing after a normal-Keychain-access check, ask the user to add or rotate it in the EnvLatch GUI. Do not silently fall back to broad `envlatch run --`; it exposes every saved key and is only for explicit user-authorized compatibility use.
11. If the command is already running without its key or endpoint metadata, restart it through the wrapper; environment variables cannot be added safely to an existing process.

## Secret handling

- Never print, echo, log, inspect, or ask EnvLatch to reveal a stored value.
- Treat endpoint and key-group metadata as routing configuration, never as a place to store a key. `groups create` accepts saved key names only. Secret values belong only in the EnvLatch GUI and macOS Keychain.
- Never dump the launched environment or write a stored value to `.env`, a shell profile, a command argument, a prompt, or a repository file.
- Never replace the wrapper with `eval`, command substitution, or a shell export pipeline.
- Treat the launched program and every descendant as able to read every value selected by that key or key group.
- A `--using` launch exposes only its complete validated selection under saved names and configured client bindings. Repeated saved-key selections are validated together before any value is read. A broad launch without `--using` exposes every saved key.
- Ask the user to add or rotate a missing value in the EnvLatch GUI; do not solicit the plaintext in chat.
- For an HTTP authorization header, reject CR/LF and unsupported control characters in the consumer before transport, using a constant diagnostic. Some header-validation exceptions contain the entire credential value; catching and logging that exception can leak it. Do not normalize the vault value or apply this single-line restriction to unrelated secrets. [Verified Python boundary](references/http-header-diagnostics.md).

## Approved creation of a new provider credential

The default missing-key path remains a human GUI handoff. When the owner specifically authorizes creating and storing a new provider credential, follow the host's confirmation rules at the grant action and save it through EnvLatch's secure form. Changing an existing credential still requires the host's credential-change handoff.

Before generating a one-time value, prepare the target environment name and secure field. Keep the result-page binding. Suppress automatic state output before the generated screen can appear; do not emit a raw accessibility/DOM snapshot or screenshot of that screen. Provider secrets can occur in button names and ordinary text nodes, so masking only `Value:` lines or one guessed prefix is insufficient.

Transfer only the newly generated, authorized value through an opaque UI binding into the secure field. Never print it, interpolate it into command arguments, or write it to a temporary file. Verify the saved name and provider scope without retrieving the stored value, then clear transient bindings and leave the one-time screen. Never use this procedure to reveal an existing vault item.

If a result screen exposes a generated credential in output, stop using that credential, report the incident and obtain the required revocation/replacement confirmation. Verify revocation and store the replacement without exposing its value. A saved credential name is not proof that the recipient API accepts it.

When a recipient expects an ID variable whose name the GUI does not accept, save it under an allowed `_CREDENTIAL` name and use a narrow selected-key child adapter for that exact alias. Do not use endpoint/group metadata for secret values or broaden the key selection.

## Native line-oriented credential prompts

- EnvLatch preserves saved UTF-8 values, including whitespace and line breaks. It does not redact child output. A saved name ending in `_CREDENTIAL` does not encode or transform the value.
- For fields whose recipient contract is a single line, such as `notarytool` Apple ID, team ID and app-specific password, use a selected-key child adapter to trim outer pasted whitespace and refuse empty or embedded CR/LF before submission. Do not apply this rule to arbitrary secrets whose whitespace may be meaningful, and do not rewrite the vault.
- Feed these values only to the recipient's native prompts. Disable terminal capture before the first credential entry; retain only status or normalization counts, never values, lengths or secret-derived hashes. Preserve the exact program, authentication validation and selected-key scope.
- Qualify prompt transport with public dummy byte receipts on the actual terminal path. A sandbox `/dev/tty` denial can make libc `getpass` fall back to stdin; that is setup evidence and does not qualify secure terminal behavior. Native prompt timing is distinct from notarytool's undocumented internals.
- An HTTP 401 is not proof that the stored password is wrong. Check the exercised input boundary before requesting rotation. The Selenar alternate-account case had one outer-whitespace normalization and then successful profile creation and fresh Apple authentication; its specific normalized field was not inspected. [Verified account and input record](/Users/kehualin/Documents/projects/onyourfeet/docs/release/2026-10-05-gumroad-publication.md).
