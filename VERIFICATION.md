# EnvLatch v0.2.1 verification

Date: 2026-07-28
Platform: macOS arm64
Code candidate: `c24eccd5ef3cb913cf3423c2765c51d57f61a6e1`

## Release verdict

**SHIPPED AS A SIGNED AND NOTARIZED PUBLIC BINARY**

The provider-aware dashboard, provider-agnostic launch behavior, repeated
saved-key selection, create-only key groups, installed canonical skill,
Keychain behavior, signed arm64 ZIP, and signed arm64 DMG have
candidate-specific receipts. Apple accepted both v0.2.1 submissions, the
tickets are stapled, Gatekeeper accepts both artifacts as Notarized Developer
ID, and the public GitHub bytes passed the full release verifier.

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

## v0.2.0 behavior baseline

The v0.2.0 committed-source suite passed:

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

## Provider-aware dashboard refresh

Source candidate:
`514e5c12c055678ae55b8c2418c47aad0d2f907e`

The v0.2.1 exact-candidate suite passed:

```text
swift test --no-parallel
60 tests
15 suites
0 failures
exit=0
```

`scripts/build-app.sh` produced an ad-hoc-signed release app, and
`codesign --verify --deep --strict` passed. The assembled app contains the 13
locally bundled provider-logo assets plus their Lobe Icons MIT notice.

A DEBUG-only isolated model supplied synthetic key names and no secret values.
The real SwiftUI window was inspected in dark and forced-light appearances:

- saved keys render as searchable provider-aware cards;
- OpenAI, Anthropic, Gemini, OpenRouter, MiniMax, and common direct-key marks
  are recognizable at card and preset-button sizes;
- key groups remain secondary in the same scroll journey;
- Agent setup remains collapsed by default;
- Add Key presents five editable provider presets plus Custom; and
- selecting MiniMax fills `MINIMAX_API_KEY`, the Anthropic contract,
  `https://api.minimaxi.com/anthropic`, and `ANTHROPIC_AUTH_TOKEN` while the
  secure value field remains empty.

The sanitized dashboard capture is
`docs/assets/marketing/envlatch-main-demo.png`:

```text
width=880
height=700
sha256=19696e6da131919a1c4291918bb1fb409c09d8c6c7c84390a369a6e48c411a92
```

The image is embedded in both public READMEs. v0.2.1 packages this exact
provider-aware UI as a signed and notarized binary.

## v0.2.1 signed release receipt

The annotated `v0.2.1` tag resolves to:

```text
c24eccd5ef3cb913cf3423c2765c51d57f61a6e1
```

GitHub Actions run
[`30300332620`](https://github.com/Raylinkh/envlatch/actions/runs/30300332620)
completed successfully against that commit. The local release build reported
`EnvLatch 0.2.1`, and `swift test --no-parallel` passed 60 tests in 15 suites.

Apple accepted both submitted artifacts with no reported issues:

```text
zip_submission=0cb62703-9892-4edc-85f3-ff1f285e8761
dmg_submission=0cad7f06-a991-4f15-9138-7f853c084866
zip_status=Accepted
dmg_status=Accepted
```

The stapled release artifacts are:

```text
EnvLatch-0.2.1-macos-arm64.zip
bytes=1683112
sha256=da861c794ef56af0fe73b695fe8fbdb16ce52ac6809cc724edbbe9525016d08e

EnvLatch-0.2.1-macos-arm64.dmg
bytes=2050855
sha256=83eacdecaadf488c973ee786ed6ccfb9db2e1c69884e43f4f023eb223945c6f7
```

`scripts/verify-release.sh` passed locally and again after downloading all four
public assets into a fresh temporary directory:

```text
archive_checksum=passed
dmg_checksum=passed
dmg_payloads=4
architecture=arm64
signature=Developer ID Application
notarization=stapled
gatekeeper=accepted
isolated_install=passed
induced_failure_rollback=passed
exit=0
```

Public release:
https://github.com/Raylinkh/envlatch/releases/tag/v0.2.1

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

## Signed and notarized artifacts

`scripts/package-release.sh` built the app with:

```text
Developer ID Application: Kehua Lin (XHV8GP8YNW)
```

Apple notarization accepted both submitted artifacts with status code `0` and
no issues:

```text
zip_submission=59bd69de-17a7-4d37-af46-f252724d8f20
dmg_submission=36fdad12-d1c9-4d8c-ab85-8c13dcb018bf
zip_status=Accepted
dmg_status=Accepted
issues=null
```

The final distributable artifacts, created after stapling the app and DMG, are:

```text
EnvLatch-0.2.0-macos-arm64.zip
sha256=d2c19d3d06021a0051ae27fd624f77f4209760bd3925a2d912634a86aad7c3ba

EnvLatch-0.2.0-macos-arm64.dmg
sha256=85689589b01521af10f784e459a3241528d29c2057bbff156497113df08d6ccf
```

`scripts/verify-release.sh` passed:

```text
archive_checksum=passed
dmg_checksum=passed
dmg_payloads=4
architecture=arm64
signature=Developer ID Application
notarization=stapled
gatekeeper=accepted
isolated_install=passed
induced_failure_rollback=passed
exit=0
```

The verifier checks the ZIP app, DMG, mounted app, and isolated installed app;
confirms checksums and Developer ID signatures; validates stapled tickets and
Gatekeeper acceptance; compares the four mounted payloads to their source
inputs; validates the installed CLI and agent-skill links; and proves failed
installation rollback.

## Security and repository hygiene

EnvLatch has no reveal, clipboard, export, `eval`, or `.env` command.
`groups create` accepts account names only. Repeated selections and group
membership are validated with every endpoint binding before any Keychain value
is read; no last-writer conflict behavior exists.

Remaining `AgentKeyring` identifiers are the intentionally retained Keychain
service, Application Support compatibility namespace, and migration paths
documented in `SPEC.md` and `SECURITY.md`.

## Publication status

- repository: https://github.com/Raylinkh/envlatch
- v0.1.0 historical unsigned prerelease: published
- v0.2.2 tag source: `11de3c4aca5af087fc02f53379ede4153c07f061`
- CI: https://github.com/Raylinkh/envlatch/actions/runs/30422058632
  (`success`)
- stable latest release: https://github.com/Raylinkh/envlatch/releases/tag/v0.2.2
- recommended release assets: signed/notarized arm64 DMG and ZIP with adjacent
  SHA-256 checksums
- legacy v0.2.0 release assets: explicitly named unsigned arm64 DMG and checksum
- private vulnerability reporting: enabled

All four signed assets were downloaded back from GitHub into a new temporary
directory. `scripts/verify-release.sh` passed against those remote bytes,
including checksums, signatures, stapled tickets, Gatekeeper assessment,
mounted payload comparison, isolated installation, and rollback. The remote
artifacts were:

```text
EnvLatch-0.2.2-macos-arm64.zip
bytes=1684585
sha256=45568ece9cc45af67d94527485b258bc980d3d57251dcd9d25bb81c907853c87

EnvLatch-0.2.2-macos-arm64.dmg
bytes=2053601
sha256=49f0561e6f58aed1957aa7d096176e3f4a51503c302abec74797d811b63a6415
```

The v0.2.2 runtime contradiction was also verified on the exact candidate:

```text
restricted process:
saved_key_count=0
saved_key_count_scope=current_process
keychain_visibility_warning=sandboxed_zero_is_inconclusive
exit=1

normal macOS Keychain access:
saved_key_count=4
saved_key_count_scope=current_process
exit=0
```

Neither doctor path requested secret data.

The freshly downloaded public build was installed locally. One saved key was
then selected through the normal macOS approval path and supplied to a
no-output local child assertion:

```text
selected_key_launch=passed
cli_link=installed
agent_pairing=paired
```

The child checked only whether the selected environment variable was non-empty.
No value was printed and no provider request was made.

## Known boundaries

- Replacing an ad-hoc-signed executable can change its Keychain identity and
  cause one authorization prompt per existing key. Entering the login password
  and choosing **Always Allow** updates that item's access list; choosing
  **Allow** authorizes only one read. Future releases must retain the same
  Developer ID identity.
- Touch ID user-presence access control would gate Keychain reads and prevent
  unattended agent launches, so biometric-per-read is not the default v0.2
  contract.
- The old explicitly named unsigned DMG remains a legacy preview and still
  requires **Privacy & Security → Open Anyway**.
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

# v0.3.0 source candidate — 2026-07-29

The Simplified Chinese GUI source candidate is public but is not yet a signed
binary release.

- Exact source: `77478bc74e73ec82940ead6c96e9be41ecee5c9e`
- Public CI: `30428180335` — success
- Local assembled proof: 65 tests in 16 suites passed; the release-mode app
  reported `EnvLatch 0.3.0`, carried
  `Contents/Resources/zh-Hans.lproj/Localizable.strings`, passed strict
  code-signature verification, and preserved English CLI output.
- Localization proof: every GUI key has a Simplified Chinese catalog entry,
  the checked runtime mirror matches the catalog, and critical static,
  interpolated, count, status, and validation messages resolve in both
  locales.
- Pending boundary: real English and Simplified Chinese window inspection,
  Developer ID signing, notarization, public release assets, and public-asset
  re-download verification.
