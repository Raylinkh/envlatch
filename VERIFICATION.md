# EnvLatch v0.2.0 verification

Date: 2026-07-27
Platform: macOS arm64
Code candidate: `9204fda08b011582dd94dbfa041e3167a35d0fd3`

## Release verdict

**READY FOR PUBLIC SOURCE AND AN EXPLICITLY UNSIGNED PREVIEW**

The committed source, release build, repeated saved-key launch, create-only
CLI key groups, installed canonical skill, Keychain behavior, and unsigned
arm64 DMG have candidate-specific behavioral receipts. The DMG remains an
ad-hoc-signed preview, not a Developer ID signed or notarized distribution.
Gatekeeper rejects it until the user chooses **Open Anyway**.

## RED to GREEN

The first focused test run failed at compile time because the public CLI command
had no repeated selection or group-creation cases and `CLIApplication` had no
multi-selection preparation method:

```text
incorrect argument label: expected profile, received selections
CLICommand has no member createGroup
extra argument selections in call
exit=1
```

After the implementation, the focused parser, application, and create-only
store suite passed:

```text
24 tests
3 suites
0 failures
exit=0
```

## Exact-candidate tests

`swift test --no-parallel` passed from the committed source:

```text
55 tests
14 suites
0 failures
exit=0
```

Process tests run globally without parallelism because both use `fork` followed
by direct `execve`; Swift Testing's suite-level serialized trait does not order
unrelated suites.

Coverage includes:

- strict repeated `--using <saved-key>` parsing with literal arguments after
  the `--` separator;
- `groups create <name> --using <saved-key> ...` parsing and create-only
  persistence;
- missing, duplicate, group-composed, ambiguous, and endpoint-conflicting
  selections failing before any secret read;
- missing, duplicate, conflicting, normalized-name-colliding, or existing
  CLI-created groups leaving group storage unchanged and reading no value;
- rejected group creation previewing legacy endpoint migration without
  persisting that migration;
- repeated two-key selection through parser, real default Keychain, endpoint
  alias/base-URL mapping, and direct `execve`, with one unselected sentinel;
- direct saved-key and saved-group compatibility;
- real default-Keychain add, replace, repeated prompt-disabled read, and
  idempotent cleanup;
- canonical executable and symlink resolution before credential reads;
- literal-argument and PID preservation without shell interpolation;
- installed setup-prompt and skill content for both multi-key paths;
- credential, endpoint, transactional mutation, GUI failure, and named-host
  pairing regressions.

Test processes report only booleans, PID, and argument metadata. They never
print a value or pass one as a command argument.

Release checks also passed:

```text
zsh -n scripts/*.sh
Resources/Info.plist: OK
git diff --check
codesign --verify --deep --strict dist/EnvLatch.app
architecture=arm64
version=0.2.0
exit=0
```

`profiles` remains a list-only compatibility alias. `groups` is the public
inspection and creation command.

## Installed repeated-key smoke

`scripts/install.sh` installed the exact candidate to
`~/Applications/EnvLatch.app`. The CLI resolves to that bundle, the canonical
skill matches the repository byte-for-byte, and the assembled and installed
executables match:

```text
sha256=3a2ec380595c1d748c58b7908ab4dca57739099cedc491ecd0a5f7ec9f5475b3
source_installed_hash_match=true
cli_resolves_to=~/Applications/EnvLatch.app/Contents/MacOS/EnvLatch
installed_skill_matches_repository=true
```

The installed candidate selected two existing keys and left a third saved key
unselected:

```text
envlatch run \
  --using FISH_AUDIO_API_KEY \
  --using MINIMAX_API_KEY \
  -- <local no-network verifier>
```

The verifier emitted booleans only:

```text
first_present=True
second_present=True
alias_present=True
base_matches=True
unselected_absent=True
exit=0
```

This proves the installed repeated-key path exposes both selected saved names,
applies the configured MiniMax Anthropic credential alias and base URL, and
leaves `OPENROUTER_API_KEY` absent. It made no network call and emitted no value
or digest.

Replacing the earlier ad-hoc-signed executable required one Keychain approval
for the new code identity. An immediate second two-key run with the unchanged
v0.2.0 executable completed without another prompt:

```text
repeat_first_present=True
repeat_second_present=True
repeat_unselected_absent=True
exit=0
```

## CLI-created group proof

The CLI application test used an isolated user-only group store and a recording
secret store:

```text
envlatch groups create Backend \
  --using OPENAI_API_KEY \
  --using GITHUB_TOKEN

created_group=Backend
keys=OPENAI_API_KEY,GITHUB_TOKEN
```

The persisted JSON contains those names only. `load` and `loadAll` remained at
zero. Separate cases proved missing keys, endpoint conflicts, key/group
collisions after group-name normalization, duplicate membership,
case-insensitive existing-group replacement, and rejected legacy-migration
preview all fail before a write or secret read.

The built and isolated-installed CLI help contains both accepted forms, and the
bundled/installed skill contains the same commands:

```text
envlatch run --using <saved-key> --using <saved-key> -- <program> [args...]
envlatch groups create <group-name> --using <saved-key> [--using <saved-key> ...]
```

Pairing remains optional setup status. It grants no authorization and is not
required to use either command.

## Fresh-process UI receipt

The installed app was fully quit and relaunched before accessibility
inspection, avoiding a stale in-memory v0.1 process. The fresh v0.2 window:

- kept **Key groups** collapsed by default and showed the saved group count;
- showed paired agents/hosts in the expandable **Agent setup** section;
- taught repeated `--using` for a one-off multi-key command;
- taught `groups create` for a reusable non-secret group;
- stated that group creation accepts names only and never reads values; and
- stated that pairing is status, not authorization.

The inspection exposed local key and host names to the local accessibility
client, so no screenshot or machine-specific names are included in this public
receipt.

## Unsigned preview artifact

`scripts/package-unsigned-preview.sh` created:

```text
dist/EnvLatch-0.2.0-macos-arm64-unsigned.dmg
bytes=1914224
sha256=65e864d68afbb5e716d40772b027d0e480778cfd40cebf8f857054a8ddd8874b
```

`scripts/verify-unsigned-preview.sh` passed:

```text
EnvLatch-0.2.0-macos-arm64-unsigned.dmg: OK
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

The verifier compares mounted app and installer inputs with the assembled
candidate, installs into an isolated root, verifies CLI/skill links and v0.2
help/skill content, injects an install failure, and confirms rollback.

## Security and repository hygiene

EnvLatch has no reveal, clipboard, export, `eval`, or `.env` command.
`groups create` accepts account names only. Repeated selections and group
membership are validated with every endpoint binding before any Keychain value
is read; no last-writer conflict behavior exists.

Remaining `AgentKeyring` identifiers are the intentionally retained Keychain
service, Application Support compatibility namespace, and migration paths
documented in `SPEC.md` and `SECURITY.md`.

## Publication status

At this receipt revision:

- repository: https://github.com/Raylinkh/envlatch
- v0.1.0 historical unsigned prerelease: published
- v0.2.0 source commit and unsigned preview: verified locally, not yet pushed
  or published
- private vulnerability reporting: enabled

This section must be updated with the remote commit, CI run, release URL, and
downloaded-back checksum before v0.2.0 publication is called complete.

## Known boundaries

- `spctl --assess --type execute` rejects the candidate (exit 3) because it is
  ad-hoc signed.
- This Mac has no valid Developer ID Application identity and no notarization
  profile. The unsigned DMG requires **Privacy & Security → Open Anyway**.
- Replacing an ad-hoc-signed executable can change its Keychain identity and
  cause one authorization prompt per existing key. The unchanged installed
  v0.2 executable read the same two selected items again without another prompt.
  Developer ID signing is the durable upgrade-stable fix.
- EnvLatch injects environment variables; it is not an egress proxy or
  sandbox. The launched process and descendants can read selected values.
- The caller's inherited environment is preserved. Unselected EnvLatch items
  are not read, but pre-existing parent variables are not scrubbed.
- Group-file replacement uses Foundation's atomic write and user-only
  permissions but does not add a multi-process writer lock. Concurrent group
  mutations are outside the v0.2 single-user CLI contract.
- The file-based Keychain ACL APIs are deprecated. They are used for the
  trusted-executable behavior and require ongoing macOS compatibility testing.

Any change to Keychain queries, saved-key/group resolution, environment
construction, execution, signing, bundle layout, installer migration, or
release packaging invalidates the corresponding receipt above.
