# EnvLatch v0.1.0 verification

Date: 2026-07-26
Platform: macOS arm64
Code candidate: `8ce696d`

## Release verdict

**PUBLIC-SOURCE BOUNDARY-READY**

The source candidate, app assembly, transactional installation, GUI-to-Keychain
configuration, and installed two-selected/one-unselected execution path are
verified. EnvLatch is ready to create and push as a public source repository.
It is not yet published, and no downloadable binary is claimed; the current
Mac has no Developer ID Application identity.

## Exact-candidate product behavior

`swift test` passed from the committed source:

```text
43 tests
14 suites
0 failures
exit=0
```

Coverage includes:

- credential-name and value validation;
- attribute-only Keychain listing with every list/item query pinned to the
  user's exact default Keychain;
- additions explicitly targeted to that same Keychain;
- real default-Keychain add, replace, read, and idempotent cleanup under
  isolated test services;
- parser to named launch profile to two selected real-Keychain values, one
  unselected sentinel, per-key Anthropic/OpenAI-compatible bindings, and direct
  `execve`;
- distinct provider records with the same display label;
- refusal of endpoint URLs containing credentials, queries, or fragments;
- symlink resolution to a canonical executable before any credential read;
- direct-execution PID and literal-argument preservation;
- missing-member and credential/configuration conflicts before secret reads;
- transactional endpoint rollback when a Keychain save fails;
- visible, redacted GUI behavior when Keychain access is denied;
- refusal to delete a key referenced by a launch profile;
- any-name host registration, installation inspection, and safe CLI parsing.

The purpose-built direct-execution child receives only expected digests and
reports booleans, PID, and argument metadata. Secret values are not placed in
arguments or test output.

## App assembly and installation

The release build completed and the app bundle passed:

```text
Resources/Info.plist: OK
EnvLatch 0.1.0
AppIcon.icns=present
codesign --verify --deep --strict=0
architecture=arm64
```

`scripts/install.sh` installed the exact code candidate to
`~/Applications/EnvLatch.app`. The canonical CLI symlink resolves into that
bundle. The install-time doctor passed before the app transaction committed:

```text
platform=macOS
keychain_attribute_query=reachable
saved_key_count=2
cli_link=installed
agent_pairing=paired
paired_host_count=1
endpoint_profile_count=1
launch_profile_count=1
```

The assembled and installed executable bytes are identical:

```text
sha256=0e877b66efa542fdfe8ae34137db72155446427a79db139a55bdd8a3c191914a
```

The Codex, Claude Code, and Gemini CLI discovery links resolve to the same
canonical `~/.agents/skills/envlatch` directory. They are conveniences rather
than an allowlist; `envlatch pair <name>` accepts any valid agent or host name
and does not authorize credential access.

Isolated installer receipts cover initial install, upgrade, and injected
failure. The failure case restored both current and legacy app paths. Pairing
receipts cover first install, idempotent rerun, preflight failure, and forced
post-install doctor failure; the latter restored the prior CLI, skill, and
three discovery links. Staging residue was zero.

## Installed least-privilege credential smoke

The exact installed GUI created a temporary disposable sentinel, configured a
second non-secret endpoint binding without re-entering its existing value, and
created a temporary launch profile selecting both existing keys but not the
sentinel. The verifier was launched from a parent environment with all relevant
credential, alias, and base-URL variables explicitly absent. It reported only:

```text
selected_a_present=True
selected_b_present=True
alias_a_matches=True
alias_b_matches=True
base_a_matches=True
base_b_matches=True
unselected_absent=True
literal_argument_preserved=True
pid_preserved=True
```

That receipt proves both selected values were read from the default Keychain,
mapped to their Anthropic- and OpenAI-compatible client variables, paired with
their configured base URLs, and inherited like normal `.env` variables. The
unselected item was not read; literal shell metacharacters were not
interpreted; and the wrapper PID survived direct `execve`. The verifier never
printed a value or received one in a command argument.

Postflight cleanup removed the temporary launch profile and disposable
Keychain item, removed the temporary second endpoint binding, and confirmed
the original state:

```text
saved_key_count=2
endpoint_profile_count=1
launch_profile_count=1
temporary_state_absent=true
```

## Secret handling and repository hygiene

A controlled earlier verifier received the two existing values only in its
process environment and recursively scanned the repository, Git history,
build tree, and assembled app. It reported:

```text
credential_values_present=True
repo_secret_leak_hits=0
```

The source contains no reveal, clipboard, export, `eval`, or `.env` command.
Endpoint URLs reject embedded credentials, queries, and fragments before
persistence, because profile metadata is displayed by safe inspection
commands. Remaining `AgentKeyring` identifiers are the intentionally retained
Keychain service, Application Support compatibility namespace, and legacy
backup paths documented in `SPEC.md` and `SECURITY.md`.

## Public repository surface

Present and validated:

- MIT `LICENSE`;
- `SECURITY.md` with a private-reporting path and explicit threat boundary;
- GitHub Actions on `macos-15` using the current `actions/checkout@v7`, with
  tests, syntax checks, bundle assembly, version/icon checks, and code-sign
  verification;
- source-install and binary-release instructions that distinguish ad-hoc
  source builds from trusted distribution;
- a public-safe README screenshot with credential and host metadata removed;
- a fail-closed `package-release.sh` that exits 64 without a Developer ID
  identity and notary profile, derives the archive architecture from the
  executable, and writes a portable checksum record.

Outside the restricted reviewer sandbox, `gh auth status` succeeded for
`Raylinkh` on 2026-07-26. `Raylinkh/envlatch` did not exist, and this local
repository had no remote. Repository creation and public push have not been
performed.

## Known boundaries

- `spctl --assess` rejects the installed candidate because it is ad-hoc signed.
- The current Mac has zero valid code-signing identities.
- A downloadable binary must not be published until Developer ID signing,
  notarization, stapling, Gatekeeper assessment, and checksum generation all
  succeed through `scripts/package-release.sh`.
- EnvLatch injects environment variables; it is not an egress proxy or
  sandbox. The launched process and descendants can read selected values.
- Least privilege applies to EnvLatch-managed Keychain reads. The caller's
  inherited environment is preserved and is not scrubbed.
- The trusted-application ACL gives the EnvLatch executable prompt-free access
  after authorization. Keychain may still let a user approve another client
  interactively. The file-based Keychain ACL APIs are deprecated; a stable
  Developer ID identity is the supported binary-distribution path.

Any change to Keychain queries, profile resolution, environment construction,
execution, signing, bundle layout, installer migration, or the release script
invalidates the relevant receipt above.
