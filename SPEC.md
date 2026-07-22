# AgentKeyring v1 Product Contract

Status: revised for open named-host pairing and endpoint profiles; pending final independent re-review
Decision owner: Kehua
Decision: personal tool; no demand or public-launch claim
Meta-budget: one native app, one bundled executable, one portable skill, no server, sync, proxy, provider plugin, or custom cryptography

## Outcome and boundaries

AgentKeyring gives one Mac user a single secure place to enter API keys and a single launch command that makes those keys available to any explicitly paired agent, host, or local process. Optional endpoint profiles bind one Keychain item to non-secret provider, wire-contract, base-URL, and target environment-name metadata without introducing provider-specific commands.

The selected slice is complete when the user can save a named environment variable in the GUI, optionally configure its endpoint profile, pair any self-named host once, and prove either `agent-keyring run -- <command>` or `agent-keyring run --using <profile> -- <command>` supplies the intended environment without AgentKeyring printing or writing a secret.

The security claim is deliberately narrow: values are encrypted at rest by macOS Keychain and are not written to project files, shell startup files, command arguments, or AgentKeyring logs. A launched process and its descendants can read injected environment variables. AgentKeyring is not a sandbox, proxy, credential broker, or defense against a malicious agent or dependency.

### Non-goals

- Cloud sync, accounts, teams, sharing, rotation, or provider calls.
- `.env` export, `eval` output, clipboard copy, reveal, or a generic `get` command.
- Shell-profile mutation or provider-specific commands.
- Arbitrary headers, model routing, failover, per-agent secret scopes, short-lived credentials, or biometric-per-read policy in v1.
- Replacing OAuth flows already managed by an agent CLI.

## Binding requirements

- **AK-1 — Store once:** The GUI accepts a safe credential environment name and a non-empty, NUL-free value, then adds or replaces one exact generic-password item in the AgentKeyring service in the file-based login Keychain.
- **AK-2 — Never render values:** The main window lists names, masked state, and optional non-secret endpoint metadata only. It never fetches secret data merely to render the list. Edit uses a fresh secure field; delete requires confirmation. Profile metadata contains a provider label, API contract, base URL, Keychain account reference, and target credential environment name—never the value.
- **AK-3 — Explicit release:** Both launch shapes resolve the executable against inherited `PATH` before reading Keychain. An unprofiled `run --` overlays the saved set; a `run --using` launch loads only the referenced Keychain item and derives its configured credential/base-URL bindings. Both directly call `execve` with the original argument vector, never a shell or constructed command string.
- **AK-4 — Useful failures:** Invalid names, empty values, duplicate replacement, missing commands, Keychain denial/lock/cancel, and launch failure have specific messages and a safe retry or exit.
- **AK-5 — One identity:** The GUI and CLI are the same signed executable. The installed CLI is a symlink to the executable inside the app bundle so Keychain access is not split across two binaries. New items carry an explicit ACL that trusts only that executable. V1 is intentionally not App-Sandboxed because its accepted purpose is to replace itself with arbitrary user-selected local tools. It uses the non-synchronizing file-based login Keychain; a local ad-hoc signature is supported but may require Keychain reauthorization after an app rebuild. A stable Developer ID signature, when supplied, is preserved by packaging.
- **AK-6 — Pair and inspect safely:** One setup installs the CLI and one canonical skill. Built-in discovery links are conveniences; `agent-keyring pair <name>` registers any agent or host by a validated display name. The collapsible GUI lists those names and shared-setup status dynamically. Its copy action copies a complete setup prompt containing pair, doctor, help, profiles, and run instructions. `list`, `profiles`, and `doctor` never read or print values.
- **AK-7 — Accessible native UI:** All actions are keyboard reachable, fields have labels, destructive actions use the standard confirmation role, status is conveyed in text as well as color, and the UI honors system appearance and reduced-motion settings by using standard SwiftUI controls with no decorative animation.

## Product loop

| Beat | User action | System responsibility | Truth shown | Recovery |
|---|---|---|---|---|
| 1 | Launch app | Query Keychain attributes for this service | Empty guidance or saved names | Retry refresh after access error |
| 2 | Choose Add Key | Present name, secure value, and optional endpoint fields | Nothing is saved yet | Cancel returns unchanged |
| 3 | Save | Validate Keychain value and non-secret profile separately | Saved name, contract, and endpoint; value hidden | Edit metadata without re-entering the current value |
| 4 | Pair once | Agent or host supplies its own display name | Dynamic named-host list and shared setup status | Repeat the idempotent pair command |
| 5 | Launch agent | Load all raw keys or one selected profile, then replace wrapper process | No secret output | Nonzero exit with launch error |
| 6 | Rotate or remove | Replace through secure field or confirm delete | Updated name list only | Cancel preserves accepted state |

## State, data, and invariants

The durable secret authority is the user's normal file-based login Keychain. Each secret is a non-synchronizing generic-password item with service `dev.agentkeyring.secrets`, account equal to the environment name, UTF-8 value data, and an application-only ACL. Non-secret endpoint profiles and named-host records are separate user-only JSON files under Application Support. Profiles reference Keychain accounts; they never duplicate values. Every Keychain query pins the exact service and non-sync scope, and attribute listing omits return-data.

Environment names must match `[A-Z_][A-Z0-9_]*`, end in one of `_API_KEY`, `_TOKEN`, `_SECRET`, `_PASSWORD`, `_ACCESS_KEY`, `_PRIVATE_KEY`, or `_CREDENTIAL`, and must not start with `DYLD_` or `LD_`. This intentionally rejects `PATH`, shell hooks, language-runtime options, and loader-control variables. Values must be non-empty UTF-8 without an embedded NUL because POSIX environments cannot represent NUL. Save is an upsert; a repeated save replaces exactly one value. Delete treats `errSecItemNotFound` as idempotent success. Listing and doctor queries request attributes only; doctor reachability is not presented as proof of secret-read authorization. Any Keychain error leaves the last accepted value unchanged unless the OS reports a successful operation.

Command resolution uses the caller's inherited `PATH`, never a saved value. A program containing `/` is used only if it is an executable regular file. A bare program is resolved by scanning inherited `PATH` before any Keychain value is read; empty path segments are rejected rather than interpreted as the current directory. The resolved absolute path and original arguments are passed to `execve`, preserving the wrapper PID and avoiding `execvp`'s `ENOEXEC` shell fallback.

## Architecture spine

| Capability | Owner | Path | External boundary | Proof |
|---|---|---|---|---|
| Validation and CLI parsing | `AgentKeyringCore` | `Sources/AgentKeyringCore` | None | Unit tests, RED then GREEN |
| Secret persistence | `KeychainSecretStore` | `Sources/AgentKeyringCore` | Security.framework / `securityd` | Isolated dummy-item integration test with cleanup |
| Endpoint metadata | `EndpointProfileStore` | `Sources/AgentKeyringCore` | User-only Application Support JSON | Persistence, validation, and selected-key execution tests |
| Direct process release | `PathResolver` and `CommandRunner` | `Sources/AgentKeyringCore` | POSIX environment and `execve` | PID/argv probe plus exact-canary boolean receipt |
| Native GUI | `AgentKeyringApp` | `Sources/AgentKeyring` | SwiftUI/AppKit | Built `.app`, launched and visually inspected on macOS |
| Pairing skill | portable Agent Skills artifact plus named-host registry | `AgentSkill/agent-keyring` | Any host; built-in discovery links for common CLIs | Validator, registry tests, and installed-link checks |
| Packaging/install | shell scripts | `scripts` | app bundle, code signing, CLI/skill symlinks | Signature, bundle and pairing checks |

Dependency direction is `GUI/CLI -> Core -> Security/Darwin`. Keychain queries have one implementation. Validation is pure. UI owns drafts and intent only; it does not own durable truth.

## Error and dead-end matrix

| Case | Visible behavior | Safe action | Preserved state |
|---|---|---|---|
| Empty vault | Explains Add Key and launch flow | Add Key | Empty Keychain service |
| Invalid/empty input | Inline validation, Save disabled or rejected | Edit or cancel | Existing item unchanged |
| Existing name | Save copy says Replace; upsert is atomic | Replace or cancel | Old value until success |
| Unsafe name / embedded NUL | Validation explains credential-name/value policy | Edit or cancel | Existing item unchanged |
| Keychain denied/locked | Error text names Keychain and OS status | Unlock/allow, then retry | Last accepted items |
| Delete cancel/failure | Row remains | Cancel or retry | Existing item |
| Missing `--` or command | CLI usage and nonzero exit | Correct command | Keychain untouched |
| Empty vault at `run` | CLI refuses to launch without a saved credential | Add a key in the GUI | Keychain remains empty |
| Path resolution / `execve` failure | Program name and OS error, never environment | Correct inherited PATH/name or executable | Keychain untouched |
| Missing/stale pairing | GUI and doctor report shared setup state; prompt gives `agent-keyring pair <name>` | Run pairing again | Keychain untouched; replaced paths are backed up |
| Unknown endpoint profile | CLI names the missing profile and points to `profiles` | Select an existing profile or edit one in GUI | Keychain untouched |
| Relaunch | Attribute query rebuilds list | Retry on error | Keychain remains authority |

## Walking-skeleton proof

Candidate identity is the release build produced from one commit and its recorded code-signing requirement. The P1 scenario generates a high-entropy canary only inside the test process, ensures the variable is initially absent, and saves it as `AGENT_KEYRING_TEST_TOKEN` through the real login Keychain. A Keychain query spy proves list/doctor request attributes but not data. The installed symlink is resolved and shown to target the exact executable inside the signed app bundle; GUI save followed by CLI launch proves cross-surface access. A purpose-built child receives a non-secret expected digest, returns only `exact_value=true`, reports its PID and argument count, and proves the wrapper PID was preserved and arguments were not shell-interpreted. Captured stdout/stderr, the process argument vector, repository, build logs, and declared application-support paths are scanned to ensure the canary never appeared. Replacement is proved with a second canary and the same account; cleanup runs in `defer` and a preflight/postflight sweep removes only the named disposable test item.

Negative proof covers each rejected credential-name category, embedded NUL, empty value, empty vault, missing `--`, missing executable, non-executable path, Keychain denial/interaction failure where safely injectable, delete-not-found, and stale CLI symlink. An unrelated probe binary queries the disposable item with authentication UI disabled and must be denied; the app/CLI candidate must still read it. The built app is launched on the current Mac and inspected for empty, add, saved, replace, delete-confirmation, Keychain-error, and CLI-link states. Keyboard-only traversal, accessibility labels, text status independent of color, light/dark appearance, and Reduce Motion are checked at the native surface.

Evidence is invalidated by changes to the Keychain query identity, accessibility/access-control policy, CLI parsing, environment construction, exec path, signing, bundle layout, or install symlink.

The current non-secret receipts are recorded in [VERIFICATION.md](VERIFICATION.md).

## Prior art and deferred decisions

The execution model follows the established `envchain namespace command` pattern and its direct environment-plus-exec boundary. Current Quotio and CLIProxyAPI schemas demonstrate that provider identity, API contract, base URL, and credential binding are separate operational fields. AgentKeyring adopts only that minimal environment-assembly seam; it does not adopt their proxy, routing, model-map, header, or failover scope.

Per-agent secret scopes, arbitrary headers, models, routing, and user-presence/biometric reads are deferred. Adding any changes the release contract and invalidates AK-3 proof.

## Review and acceptance

A fresh reviewer must return `ACCEPT` or `REVISE` against orphan states, unsafe claims, Keychain identity, direct-exec behavior, accessibility, and proof sensitivity. After acceptance, every implementation slice and test must reference AK-1 through AK-7. This document becomes accepted only after the blocking findings are resolved.
