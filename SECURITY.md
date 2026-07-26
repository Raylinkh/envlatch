# Security policy

## Supported versions

EnvLatch is pre-1.0 software. Security fixes are applied to the latest source
release only.

| Version | Supported |
| --- | --- |
| 0.1.x | Yes |
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

EnvLatch stores credential values in the user's non-synchronizing login
Keychain and releases them only as environment variables of an explicitly
launched process. It has no command to reveal, export, or copy stored values.

This is not process isolation. A launched process and its descendants can read
the variables selected for that launch. Debuggers, crash reporters, malicious
dependencies, and provider-side compromise are outside EnvLatch's protection
boundary. Use scoped provider credentials and spending limits.

The public EnvLatch rename intentionally retains the existing internal
Keychain service `dev.agentkeyring.secrets` and Application Support directory
`AgentKeyring`. This avoids copying credential values during migration.
Previously authorized local binaries are not automatically removed from legacy
Keychain access-control lists.

Source installs are ad-hoc signed unless a signing identity is supplied.
Rebuilding an ad-hoc-signed app can trigger a new Keychain authorization
prompt. Downloadable binary releases must be Developer ID signed, notarized,
and stapled before they are described as trusted downloads.
