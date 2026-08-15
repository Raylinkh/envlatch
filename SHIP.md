# EnvLatch ship envelope

Latest release: v0.3.0
Shipped: 2026-08-15
Slice: Native English and Simplified Chinese GUI with unchanged CLI and agent
contracts, plus native Settings for language and build identity.
Status: signed and notarized arm64 DMG and ZIP published from tag source
`e36d9bd4951f00ffa3e302ec38da20fe3a54d877`; exact-tag CI and fresh-download
verification passed.

## Current stable release

Exposure surface: https://github.com/Raylinkh/envlatch
Target ship date: 2026-08-15
Wedge: One Mac user stores API credentials in macOS Keychain and uses one or repeated `--using <saved-key>` selectors—or one reusable key group—to launch any local command with a least-privilege environment without writing a `.env` file.
Product contract: [SPEC.md](SPEC.md)
Acceptance source: [VERIFICATION.md — Release verdict](VERIFICATION.md#release-verdict)
Deferred: Cloud sync, teams, secret reveal/export, provider calls, proxying, model routing, per-agent policy, biometric-per-read, and decorative branding.
Shipped: yes — 2026-08-15

## Publication receipt

- Public source: https://github.com/Raylinkh/envlatch
- Signed and notarized arm64 release:
  https://github.com/Raylinkh/envlatch/releases/tag/v0.3.0
- v0.3.0 adds native English/Simplified Chinese UI, native language and build
  Settings, SwiftPM `swiftbuild` localization compatibility, and successful
  upgrade-backup cleanup without changing CLI or Keychain contracts.
- Public CI run `31873242630` passed on exact tag source
  `e36d9bd4951f00ffa3e302ec38da20fe3a54d877`.
- Apple accepted ZIP submission `b62081a2-d30d-4bc3-881c-128c476536c4`
  and DMG submission `59583136-9c5d-4c8f-94db-113e97e26aaf`.
- All four public assets were downloaded into a fresh directory and passed
  checksum, signature, stapling, Gatekeeper, mounted-payload,
  isolated-install, repeated-upgrade cleanup, agent-skill-link, and rollback
  verification.
- GitHub private vulnerability reporting enabled.
- The explicitly named v0.2.0 unsigned DMG remains a legacy preview.
