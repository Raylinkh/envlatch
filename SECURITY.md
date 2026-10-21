# Security policy

## Supported versions

EnvLatch is pre-1.0 software. Security fixes are applied to the latest source
release only.

| Version | Supported |
| --- | --- |
| 0.2.x | Yes |
| 0.1.x | No |
| Older | No |

## Reporting a vulnerability

Please use GitHub's private vulnerability reporting for this repository. Do
not open a public issue containing a credential, proof-of-concept secret, or
private system detail.

Include the affected version or commit, macOS version, reproduction steps,
expected and observed behavior, and the smallest non-secret evidence that
demonstrates impact. Use disposable canary credentials in any reproduction.

If private vulnerability reporting is not enabled yet, open a public issue
that asks the maintainer to enable a private report, without disclosing the
vulnerability.

## Security boundary

EnvLatch stores credential values in the user's non-synchronizing default
Keychain and releases selected values as environment variables of an explicitly
launched process. It has no command to reveal values or export a vault.

The paired Mac transfer source draft adds an opt-in copy of one exact saved key
directly into a specifically pinned target Mac's Keychain. It requires macOS 14+,
public-fingerprint verification and explicit local approval on both Macs. It is
not part of the published v0.3.0 binary. Existing setup/display-name pairing does
not grant transfer authority. Target insertion is create-only; no source deletion,
target replacement, background sync, group transfer or endpoint-profile transfer
is supported. [Transfer contract and evidence](docs/features/paired-key-transfer/STATUS.md).

Apple CryptoKit authenticated HPKE protects transfer contents and authenticates
the pinned peers. The application binds approval to the exact saved name, both
peer fingerprints, operation UUID and fresh challenge. Private device keys live
in a separate non-synchronizing Keychain service; peer and operation files contain
public metadata only. No credential value is sent through standard output,
standard error, arguments, clipboard, temporary files, or diagnostics. Interrupted
delivery can leave an unknown outcome; a receipt confirms a historical commit,
and retries cannot overwrite or automatically resend a value.

HPKE does not conceal network addresses or message lengths, and compromise of a
recipient's static private key can expose recorded past ciphertext. It is not a
forward-secrecy or malicious-local-process isolation claim. [RFC 9180 security
considerations](https://www.rfc-editor.org/rfc/rfc9180.html#section-9).

This is not process isolation. A launched process and its descendants can read
the variables selected for that launch. Debuggers, crash reporters, malicious
dependencies, and provider-side compromise are outside EnvLatch's protection
boundary. Use scoped provider credentials and spending limits.

EnvLatch preserves the caller's existing environment. Selecting one saved key,
repeating `--using` with several saved keys, or selecting one optional key group
limits which EnvLatch-managed Keychain items are read; it does not remove
credentials or configuration variables already exported by a parent process.
Repeated selections are validated as one set before any value is read. Duplicate
keys, groups mixed into a repeated selection, missing members, target-variable
collisions, and conflicting endpoint configuration fail closed without
last-writer precedence.

The public EnvLatch rename intentionally retains the existing internal
Keychain service `dev.agentkeyring.secrets` and Application Support directory
`AgentKeyring`. This avoids copying credential values during migration.
Previously authorized local binaries are not automatically removed from legacy
Keychain access-control lists.

Source installs are ad-hoc signed unless a signing identity is supplied.
Rebuilding an ad-hoc-signed app can trigger a new Keychain authorization
prompt. The recommended v0.2.2 artifacts are Developer ID signed, notarized,
stapled, and Gatekeeper-accepted. An asset explicitly named and documented as
an unsigned preview is not a trusted download: verify its SHA-256 checksum,
expect Gatekeeper's Open Anyway flow, and add credentials only after
installation from the verified artifact.

An existing item created by an older ad-hoc-signed build can prompt once when
the Developer ID build first reads it. Enter the login password and choose
**Always Allow** to update that item's trusted-application access list.
Choosing **Allow** authorizes only one read and causes another prompt later.
Touch ID access control is not a drop-in replacement: Apple's user-presence
model gates item reads and therefore conflicts with unattended agent launches.
Biometric-per-read remains outside the default v0.2 contract.
