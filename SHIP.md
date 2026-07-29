# EnvLatch ship envelope

Next release: v0.3.0
Target: 2026-07-30
Slice: Native English and Simplified Chinese GUI with unchanged CLI and agent
contracts.
Status: public source candidate `77478bc74e73ec82940ead6c96e9be41ecee5c9e`
passed CI run `30428180335`; signed/notarized binary not yet published.

## Current stable release

Exposure surface: https://github.com/Raylinkh/envlatch
Target ship date: 2026-07-29
Wedge: One Mac user stores API credentials in macOS Keychain and uses one or repeated `--using <saved-key>` selectors—or one reusable key group—to launch any local command with a least-privilege environment without writing a `.env` file.
Product contract: [SPEC.md](SPEC.md)
Acceptance source: [VERIFICATION.md — Release verdict](VERIFICATION.md#release-verdict)
Deferred: Cloud sync, teams, secret reveal/export, provider calls, proxying, model routing, per-agent policy, biometric-per-read, and decorative branding.
Shipped: yes — 2026-07-29

## Publication receipt

- Public source: https://github.com/Raylinkh/envlatch
- Signed and notarized arm64 release:
  https://github.com/Raylinkh/envlatch/releases/tag/v0.2.2
- v0.2.2 keeps the provider-aware dashboard, bundled real provider marks,
  editable presets, searchable key cards, and same-view key groups already
  verified on public `main`, and prevents agents from treating a
  sandbox-hidden Keychain query as proof of an empty vault.
- Public CI run `30422058632` passed on exact tag source
  `11de3c4aca5af087fc02f53379ede4153c07f061`.
- Apple accepted ZIP submission `56b28a30-b222-41a7-ae08-e7e8a156b2d2`
  and DMG submission `8d43911d-5943-4678-831c-7def604a2855`.
- All four public assets were downloaded into a fresh directory and passed
  checksum, signature, stapling, Gatekeeper, mounted-payload,
  isolated-install, agent-skill-link, and rollback verification.
- GitHub private vulnerability reporting enabled.
- The explicitly named v0.2.0 unsigned DMG remains a legacy preview.
