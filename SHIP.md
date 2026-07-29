# EnvLatch v0.2.2 ship envelope

Exposure surface: https://github.com/Raylinkh/envlatch
Target ship date: 2026-07-28
Wedge: One Mac user stores API credentials in macOS Keychain and uses one or repeated `--using <saved-key>` selectors—or one reusable key group—to launch any local command with a least-privilege environment without writing a `.env` file.
Product contract: [SPEC.md](SPEC.md)
Acceptance source: [VERIFICATION.md — Release verdict](VERIFICATION.md#release-verdict)
Deferred: Cloud sync, teams, secret reveal/export, provider calls, proxying, model routing, per-agent policy, biometric-per-read, and decorative branding.
Shipped: no — v0.2.2 candidate pending signed public release

## Publication receipt

- Public source: https://github.com/Raylinkh/envlatch
- Signed and notarized arm64 release candidate: v0.2.2
- v0.2.2 keeps the provider-aware dashboard, bundled real provider marks,
  editable presets, searchable key cards, and same-view key groups already
  verified on public `main`, and prevents agents from treating a
  sandbox-hidden Keychain query as proof of an empty vault.
- Signing, notarization, public upload, download-back verification, and stable
  release promotion are pending.
- GitHub private vulnerability reporting enabled.
- The explicitly named v0.2.0 unsigned DMG remains a legacy preview.
