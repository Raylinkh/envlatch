# EnvLatch v0.1.0 Product Contract

Status: accepted for public-source release after fresh coherence review on 2026-07-26
Decision owner: Kehua
Decision: owner-override; demand validation was skipped and must not be claimed
Exposure: public source at https://github.com/Raylinkh/envlatch by 2026-07-29; notarized binary distribution is separately owner-gated
Meta-budget: one native app, one bundled executable, one portable skill, no server, sync, proxy, provider plugin, or custom cryptography

## Outcome and boundaries

EnvLatch gives one Mac user a single secure place to enter API keys and one launch command that makes a named least-privilege set available to any agent, host, or local process. Endpoint metadata belongs to one saved key; a launch profile independently selects one or more saved keys. This keeps provider, wire-contract, base-URL, and target environment-name mapping separate from access selection without provider-specific commands.

The selected slice is complete when the user can save named environment variables in the GUI, optionally configure per-key endpoint metadata, configure a launch profile containing exactly the keys a command needs, optionally register a display name for setup status, and prove `envlatch run --using <profile> -- <command>` supplies only that environment without EnvLatch printing or writing a secret. Broad `envlatch run --` remains an explicitly labeled compatibility utility and cannot satisfy release acceptance.

The security claim is deliberately narrow: values are encrypted at rest by macOS Keychain and are not written to project files, shell startup files, command arguments, or EnvLatch logs. A launched process and its descendants can read injected environment variables. EnvLatch is not a sandbox, proxy, credential broker, or defense against a malicious agent or dependency.

### Non-goals

- Cloud sync, accounts, teams, sharing, rotation, or provider calls.
- `.env` export, `eval` output, clipboard copy, reveal, or a generic `get` command.
- Shell-profile mutation or provider-specific commands.
- Arbitrary headers, model routing, failover, per-agent secret scopes, short-lived credentials, or biometric-per-read policy in v1.
- Replacing OAuth flows already managed by an agent CLI.

## Binding requirements

- **AK-1 — Store once:** The GUI accepts a safe credential environment name and a non-empty, NUL-free value, then adds or replaces one exact generic-password item in the stable `dev.agentkeyring.secrets` service in the user's default file-based Keychain.
- **AK-2 — Never render values:** The main window lists names, masked state, optional non-secret endpoint metadata, and launch-profile membership only. It never fetches secret data merely to render the list. Edit uses a fresh secure field; delete requires confirmation. Endpoint metadata contains one provider label, API contract, base URL, Keychain account reference, and target credential environment name. Launch-profile metadata contains only a display name and Keychain account references. Neither contains a value.
- **AK-3 — Explicit least-privilege release:** Both launch shapes resolve symlinks and validate the final executable against inherited `PATH` before reading Keychain. `run --using` resolves the complete profile and all endpoint bindings first, rejects missing members and any duplicate target or conflicting configuration environment name, then reads only the selected Keychain items. Selected secret and configuration values override inherited variables with the same names, matching normal process-environment behavior. Broad `run --` overlays the full saved set, prints no value, is labeled as broad access in help/UI, and is excluded from release acceptance. Both directly call `execve` with the original argument vector, never a shell or constructed command string.
- **AK-4 — Useful failures:** Invalid names, empty values, duplicate replacement, missing commands, Keychain denial/lock/cancel, and launch failure have specific messages and a safe retry or exit.
- **AK-5 — One identity and compatible rename:** The GUI and CLI are the same signed executable. The installed `envlatch` CLI is a symlink to the executable inside the app bundle so Keychain access is not split across two binaries. New items carry an explicit ACL naming that executable as the sole prompt-free trusted application; macOS Keychain remains the authority and may let a user approve another client interactively. V1 is intentionally not App-Sandboxed because its accepted purpose is to replace itself with arbitrary user-selected local tools. To avoid a secret-moving migration, the rename deliberately retains the existing non-synchronizing `dev.agentkeyring.secrets` service and `AgentKeyring` Application Support directory as stable internal persistence namespaces. No second secret store exists and no value is copied. A local ad-hoc signature may require Keychain reauthorization after a rebuild; a stable Developer ID signature, when supplied, is preserved by packaging. Previously trusted binaries are not silently revoked.
- **AK-6 — Pair and inspect safely:** One setup installs the CLI and one canonical skill. Built-in discovery links are conveniences; `envlatch pair <name>` records any agent or host display name for non-authorizing setup status. Pairing is not an access-control boundary and is not required for arbitrary local commands. The collapsible GUI lists those names and shared-setup status dynamically. Its copy action copies a complete setup prompt containing pair, doctor, help, profiles, and run instructions. `list`, `profiles`, and `doctor` never read or print values.
- **AK-7 — Accessible native UI:** All actions are keyboard reachable, fields have labels, destructive actions use the standard confirmation role, status is conveyed in text as well as color, and the UI honors system appearance and reduced-motion settings by using standard SwiftUI controls with no decorative animation.

## Product loop

| Beat | User action | System responsibility | Truth shown | Recovery |
|---|---|---|---|---|
| 1 | Launch app | Query Keychain attributes for this service | Empty guidance or saved names | Retry refresh after access error |
| 2 | Choose Add Key | Present name, secure value, and optional per-key endpoint fields | Nothing is saved yet | Cancel returns unchanged |
| 3 | Save | Commit per-key non-secret endpoint metadata and Keychain value with compensating rollback | Saved name, contract, and endpoint; value hidden | Edit metadata without re-entering the current value |
| 4 | Define launch profile | Name an exact set of one or more saved keys | Membership names and derived endpoint bindings only | Edit, cancel, or remove missing/conflicting members |
| 5 | Optional setup registration | Agent or host supplies its own display name | Dynamic named-host setup list, explicitly non-authorizing | Repeat the idempotent pair command or skip it |
| 6 | Launch agent | Resolve and validate the selected profile, then load only its exact keys and replace the wrapper process | No secret output | Nonzero exit with launch error before secret reads when metadata is invalid |
| 7 | Rotate or remove | Replace through secure field; removal is blocked while a launch profile references the key | Updated name list only | Remove membership first or cancel |

## State, data, and invariants

The durable secret authority is the user's default file-based Keychain. Each secret is a non-synchronizing generic-password item with the intentionally retained service `dev.agentkeyring.secrets`, account equal to the environment name, UTF-8 value data, and a trusted-application ACL for the EnvLatch executable. Non-secret endpoint metadata, launch profiles, and named-host records are separate user-only JSON files under the intentionally retained `~/Library/Application Support/AgentKeyring` persistence namespace. Endpoint metadata references exactly one Keychain account; a launch profile contains a unique, non-empty ordered set of account names. Neither duplicates values. Every Keychain search, update, read, and delete pins the exact default Keychain, service, account where applicable, and non-sync scope; additions explicitly target that Keychain. Attribute listing omits return-data.

### Launch-profile binding rules

1. Each selected account uses its own endpoint record when present; otherwise it exposes only its saved account/environment name and contributes no base URL.
2. Endpoint records map one source account to its saved name plus at most one target credential alias and one contract-derived base-URL environment name.
3. Profile names are unique case-insensitively; member names are unique exactly; every member must exist before launch.
4. Before any secret read, EnvLatch derives all target credential names and configuration names. Two different source accounts may not target the same credential environment name. Two endpoint records may share a configuration name only when the non-secret value is identical. There is no last-writer precedence.
5. After validation, selected secret and configuration values replace inherited variables with the same names. No unselected EnvLatch account is read. Other inherited variables are preserved; EnvLatch does not scrub credentials already exported by the parent process.
6. Rotation is stable because membership references the account name. Deletion is rejected while any launch profile references the account; the user removes membership first.

Environment names must match `[A-Z_][A-Z0-9_]*`, end in one of `_API_KEY`, `_TOKEN`, `_SECRET`, `_PASSWORD`, `_ACCESS_KEY`, `_PRIVATE_KEY`, or `_CREDENTIAL`, and must not start with `DYLD_` or `LD_`. This intentionally rejects `PATH`, shell hooks, language-runtime options, and loader-control variables. Values must be non-empty UTF-8 without an embedded NUL because POSIX environments cannot represent NUL. Save is an upsert; a repeated save replaces exactly one value. Delete treats `errSecItemNotFound` as idempotent success. Listing and doctor queries request attributes only; doctor reachability is not presented as proof of secret-read authorization. Any Keychain error leaves the last accepted value unchanged unless the OS reports a successful operation.

Command resolution uses the caller's inherited `PATH`, never a saved value. A program containing `/` or found in `PATH` is resolved through symlinks and accepted only when the final target is an executable regular file. Resolution happens before any Keychain value is read; empty path segments are rejected rather than interpreted as the current directory. The canonical absolute target and original arguments are passed to `execve`, preserving the wrapper PID and avoiding `execvp`'s `ENOEXEC` shell fallback.

## Architecture spine

| Capability | Owner | Path | External boundary | Proof |
|---|---|---|---|---|
| Validation and CLI parsing | `EnvLatchCore` | `Sources/EnvLatchCore` | None | Unit tests, RED then GREEN |
| Secret persistence | `KeychainSecretStore` | `Sources/EnvLatchCore` | Security.framework / `securityd` | Isolated dummy-item integration test with cleanup |
| Per-key endpoint metadata | `EndpointProfileStore` | `Sources/EnvLatchCore` | User-only Application Support JSON | Backward-compatible persistence, mapping, and URL-policy tests |
| Named key-set selection | `LaunchProfileStore` | `Sources/EnvLatchCore` | User-only Application Support JSON | Membership, missing-member, conflict-before-read, and selected-key execution tests |
| Direct process release | `PathResolver` and `CommandRunner` | `Sources/EnvLatchCore` | POSIX environment and `execve` | PID/argv probe plus exact-canary boolean receipt |
| Native GUI | `EnvLatchApp` | `Sources/EnvLatch` | SwiftUI/AppKit | Built `.app`, launched and visually inspected on macOS |
| Pairing skill | portable Agent Skills artifact plus named-host registry | `AgentSkill/envlatch` | Any host; built-in discovery links for common CLIs | Validator, registry tests, and installed-link checks |
| Packaging/install | shell scripts | `scripts` | app bundle, code signing, CLI/skill symlinks | Signature, bundle and pairing checks |

Dependency direction is `GUI/CLI -> Core -> Security/Darwin`. Keychain queries have one implementation. Validation is pure. UI owns drafts and intent only; it does not own durable truth.

## Error and dead-end matrix

| Case | Visible behavior | Safe action | Preserved state |
|---|---|---|---|
| Empty vault | Explains Add Key and launch flow | Add Key | Empty Keychain service |
| Invalid/empty input | Inline validation, Save disabled or rejected | Edit or cancel | Existing item unchanged |
| Existing name | Save copy says Replace; endpoint metadata and Keychain changes compensate on failure | Replace or cancel | Last accepted metadata and value until success |
| Unsafe name / embedded NUL | Validation explains credential-name/value policy | Edit or cancel | Existing item unchanged |
| Keychain denied/locked | Error text names Keychain and OS status | Unlock/allow, then retry | Last accepted items |
| Delete cancel/failure | Row remains | Cancel or retry | Existing item |
| Missing `--` or command | CLI usage and nonzero exit | Correct command | Keychain untouched |
| Empty vault at `run` | CLI refuses to launch without a saved credential | Add a key in the GUI | Keychain remains empty |
| Path resolution / `execve` failure | Program name and OS error, never environment | Correct inherited PATH/name or executable | Keychain untouched |
| Missing/stale pairing | GUI and doctor report shared setup state; prompt gives `envlatch pair <name>` | Run pairing again | Keychain untouched; replaced paths are backed up |
| Unknown, incomplete, or conflicting launch profile | CLI names the missing profile/member or conflicting environment binding and points to `profiles` | Select or edit one profile | Keychain untouched and no secret read attempted |
| Delete referenced key | GUI names the launch profiles that still use it | Remove membership or cancel | Keychain item and profiles unchanged |
| Relaunch | Attribute query rebuilds list | Retry on error | Keychain remains authority |

## Walking-skeleton proof

Candidate identity is the release build produced from one commit and its recorded code-signing requirement. The P1 scenario generates three high-entropy canaries only inside the test process, ensures their variables are initially absent, and saves two selected items plus one unselected sentinel through the real default Keychain. A Keychain query spy proves list/doctor request attributes but not data. The installed symlink is resolved and shown to target the exact executable inside the signed app bundle; GUI save and launch-profile creation followed by `envlatch run --using` proves cross-surface access. A purpose-built child receives only non-secret expected digests, returns `selected_a=true`, `selected_b=true`, and `unselected_absent=true`, reports its PID and argument count, and proves the wrapper PID was preserved and arguments were not shell-interpreted. A separate conflict case must fail before the spy records any secret load. Rotation of one selected account preserves membership; deletion is blocked until the account is removed from the profile. Captured stdout/stderr, process arguments, repository, build logs, and declared persistence paths are scanned to ensure no canary appeared. Cleanup runs in `defer` and a preflight/postflight sweep removes only the named disposable items.

Negative proof also covers duplicate/empty launch membership, missing members, target credential collision, conflicting base-URL configuration, inherited-variable replacement, each rejected credential-name category, embedded NUL, empty value, empty vault, missing `--`, missing executable, non-executable path, Keychain denial/interaction failure where safely injectable, delete-not-found, and stale CLI symlink. An unrelated probe binary queries the disposable item with authentication UI disabled and must be denied; the app/CLI candidate must still read it. The built app is launched on the current Mac and inspected for empty, add, saved, launch-profile creation/edit, replace, referenced-delete refusal, delete confirmation, Keychain-error, and CLI-link states. Keyboard-only traversal, accessibility labels, text status independent of color, light/dark appearance, and Reduce Motion are checked at the native surface.

Evidence is invalidated by changes to the Keychain query identity, accessibility/access-control policy, CLI parsing, environment construction, exec path, signing, bundle layout, or install symlink.

The current non-secret receipts are recorded in [VERIFICATION.md](VERIFICATION.md).

## Prior art and deferred decisions

The execution model follows the established `envchain namespace command` pattern and its direct environment-plus-exec boundary. Current Quotio and CLIProxyAPI schemas demonstrate that provider identity, API contract, base URL, and credential binding are separate operational fields. EnvLatch adopts only that minimal environment-assembly seam; it does not adopt their proxy, routing, model-map, header, or failover scope.

Per-agent secret scopes, arbitrary headers, models, routing, and user-presence/biometric reads are deferred. Adding any changes the release contract and invalidates AK-3 proof.

## Review and acceptance

A fresh reviewer returned `ACCEPT` on 2026-07-26 after the public-source, least-privilege, binding, rename, proof, and pairing blockers were resolved. Every implementation slice and test must reference AK-1 through AK-7.

Public-source release acceptance is separate from contract acceptance. `VERIFICATION.md#release-verdict` must bind one exact commit to: the full renamed source tree; a clean-clone Swift test and release build; installed `envlatch` app/CLI/skill identity; symlinked real-tool resolution; two-selected/one-unselected least-privilege execution; conflict-before-secret-read proof; failure-safe endpoint mutation; referenced-delete behavior; secret/history scan; structural code signing; README screenshot; license/security/CI metadata; and an independent assembled-candidate security/release review. `SHIP.md` remains `Shipped: no` until the public URL is reachable. A Developer ID/notarization receipt is required only before claiming a downloadable binary release.
