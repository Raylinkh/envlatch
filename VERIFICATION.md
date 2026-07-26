# EnvLatch v0.1.0 verification

Date: 2026-07-27
Platform: macOS arm64
Code candidate: `bb730af873a496a4d9a2074d72d6a82ede4820e0`

## Release verdict

**READY FOR PUBLIC SOURCE AND AN EXPLICITLY UNSIGNED PREVIEW**

The committed source, release build, transactional installer, direct saved-key
path, optional multi-key groups, Keychain access behavior, and unsigned arm64
DMG have current behavioral receipts. The DMG is suitable only as a clearly
labeled GitHub prerelease: it is ad-hoc signed, not Developer ID signed or
notarized, and Gatekeeper rejects it until the user chooses **Open Anyway**.

## Exact-candidate tests

`swift test` passed from the committed source:

```text
46 tests
14 suites
0 failures
exit=0
```

Coverage includes:

- credential-name and value validation;
- attribute-only Keychain listing pinned to the exact default Keychain;
- real default-Keychain add, replace, read, and idempotent cleanup;
- two consecutive reads of the same disposable item with
  `LAContext.interactionNotAllowed = true`;
- direct saved-key selection through real Keychain, endpoint alias/base-URL
  mapping, and omission of an unselected sentinel;
- an optional two-key group through parser, real Keychain, and direct `execve`,
  with one unselected sentinel;
- key/group name ambiguity failing before any secret read;
- per-key Anthropic, OpenAI-compatible, and Gemini endpoint bindings;
- endpoint URL validation and transactional metadata rollback;
- canonical executable and symlink resolution before credential reads;
- literal-argument and PID preservation without shell interpolation;
- visible, redacted GUI failure handling;
- optional key-group visibility rules and any-name host pairing.

The test processes report only booleans, PID, and argument metadata. They never
print a value or pass one as a command argument.

Release checks also passed:

```text
zsh -n scripts/*.sh
Resources/Info.plist: OK
git diff --check
codesign --verify --deep --strict dist/EnvLatch.app
architecture=arm64
envlatch groups == envlatch profiles
exit=0
```

`profiles` remains a compatibility alias; `groups` is the public command.

## Exact installed direct-key smoke

`scripts/install.sh` installed the exact candidate to
`~/Applications/EnvLatch.app`. The CLI resolves to that bundle, and its
executable bytes match the assembled app:

```text
sha256=12e3ebccbbf1d5cd6dbcd61d8eab74993fdd021d0e64341e6ebc0ba74dd45ca1
source_installed_hash_match=true
cli_resolves_to=~/Applications/EnvLatch.app/Contents/MacOS/EnvLatch
```

The installed candidate was launched twice from a parent environment with the
selected key, its alias, its base URL, and an unselected saved key explicitly
absent. Both runs used the saved key name directly:

```text
envlatch run --using MINIMAX_API_KEY -- <local verifier>
```

Each run completed without user interaction or a passcode prompt and reported:

```text
selected_present=True
alias_matches=True
base_matches=True
unselected_absent=True
literal_argument_preserved=True
exit=0
```

This proves the installed saved-key path reads only `MINIMAX_API_KEY`, exposes
the same value through the configured Anthropic credential alias, injects
`ANTHROPIC_BASE_URL=https://api.minimaxi.com/anthropic`, leaves
`OPENROUTER_API_KEY` absent, and preserves literal arguments. The verifier made
no network call and emitted no value or digest.

The installed doctor reported:

```text
platform=macOS
keychain_attribute_query=reachable
saved_key_count=2
cli_link=installed
agent_pairing=paired
paired_host_count=2
endpoint_profile_count=1
launch_profile_count=1
```

Pairing records setup status only. Any valid agent or host name can pair; it
does not authorize credential access.

## Fresh-process UI receipt

Two stale pre-change processes were identified by their exact executable paths,
closed, and replaced with a fresh process from the installed candidate. The
accessibility inspection then showed:

```text
Key groups, Optional, 1
state=collapsed
```

Expanding it showed the helper text, the existing group, and **New Key Group**.
The footer says every saved key works directly with `--using KEY_NAME`, and the
expanded setup prompt instructs any agent or host to:

1. inspect saved key names with `envlatch list`;
2. inspect optional multi-key groups with `envlatch groups`;
3. run `envlatch run --using <saved-key-or-group> -- <program> [args...]`;
4. never silently fall back to broad `envlatch run --`.

The live UI contains local key names, endpoint metadata, and paired-host names,
so it is not used as the public screenshot. The README keeps the separate
public-safe screenshot with empty credential fields.

## Unsigned preview artifact

`scripts/package-unsigned-preview.sh` created:

```text
dist/EnvLatch-0.1.0-macos-arm64-unsigned.dmg
bytes=1903152
sha256=933080e390a351988161620e37850a4d3bf4a5f28ba5685c40f2a9b16ed042d3
```

`scripts/verify-unsigned-preview.sh` passed:

```text
dmg_payloads=4
architecture=arm64
signature=adhoc
isolated_install=passed
induced_failure_rollback=passed
gatekeeper_expected_rejection_exit=3
exit=0
```

The mounted DMG contains exactly:

- `EnvLatch.app`;
- `Install EnvLatch.command`;
- `UNSIGNED PREVIEW - READ ME.txt`;
- `LICENSE.txt`.

The verifier compared the mounted app and installer inputs with the assembled
candidate, performed an isolated install, confirmed the installed CLI and
skill links, injected an install failure, and confirmed rollback restored the
previous app.

## Security and repository hygiene

EnvLatch has no reveal, clipboard, export, `eval`, or `.env` command. Endpoint
metadata is non-secret and cannot contain URL credentials, queries, or
fragments. Remaining `AgentKeyring` identifiers are the intentionally retained
Keychain service, Application Support compatibility namespace, and migration
paths documented in `SPEC.md` and `SECURITY.md`.

The public surface includes an MIT license, security policy, macOS CI, source
install instructions, an unsigned-preview warning, a public-safe screenshot,
release notes, checksum generation, and fail-closed Developer ID/notary
packaging for a future trusted release.

## Published surface

The verified source and prerelease are public:

- repository: https://github.com/Raylinkh/envlatch
- tag and prerelease: https://github.com/Raylinkh/envlatch/releases/tag/v0.1.0
- release assets: the unsigned arm64 DMG and adjacent SHA-256 checksum
- repository visibility: public
- private vulnerability reporting: enabled

The two release assets were downloaded back from GitHub into a new temporary
directory. `shasum -a 256 -c` returned `OK`, and the remote DMG digest matched
`933080e390a351988161620e37850a4d3bf4a5f28ba5685c40f2a9b16ed042d3`.

The first public `main` CI run passed on macOS:

```text
CI run=30213359553
checkout=passed
script_and_metadata_validation=passed
tests=passed
app_bundle_verification=passed
unsigned_preview_packaging=passed
conclusion=success
```

## Known boundaries

- `spctl --assess --type execute` rejects the candidate (exit 3) because it is
  ad-hoc signed.
- This Mac has no valid Developer ID Application identity and no notarization
  profile. The unsigned DMG requires **Privacy & Security → Open Anyway**.
- The same installed executable read the same saved item repeatedly without a
  prompt. Rebuilding or replacing an ad-hoc-signed executable can change its
  Keychain identity and cause one authorization prompt per existing key.
  Developer ID signing is the durable upgrade-stable fix.
- EnvLatch injects environment variables; it is not an egress proxy or
  sandbox. The launched process and descendants can read selected values.
- The caller's inherited environment is preserved. Unselected EnvLatch items
  are not read, but pre-existing parent variables are not scrubbed.
- The file-based Keychain ACL APIs are deprecated. They are used for the
  trusted-executable behavior and require ongoing macOS compatibility testing.

Any change to Keychain queries, saved-key/group resolution, environment
construction, execution, signing, bundle layout, installer migration, or
release packaging invalidates the corresponding receipt above.
