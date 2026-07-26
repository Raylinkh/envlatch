# EnvLatch v0.1.0 ship envelope

Exposure surface: https://github.com/Raylinkh/envlatch
Target ship date: 2026-07-29
Wedge: One Mac user stores API credentials in macOS Keychain and uses `envlatch run --using <profile> -- …` to launch any local command with one named, least-privilege environment without writing a `.env` file.
Product contract: [SPEC.md](SPEC.md)
Acceptance source: [VERIFICATION.md — Release verdict](VERIFICATION.md#release-verdict)
Deferred: Cloud sync, teams, secret reveal/export, provider calls, proxying, model routing, per-agent policy, biometric-per-read, decorative branding, and a friction-free notarized binary until a Developer ID identity is available.
Shipped: no

## Owner-gated publication steps

- Create the public `envlatch` repository and push the verified source commit.
- Enable GitHub private vulnerability reporting after repository creation.
- Attach the explicitly labeled unsigned arm64 preview DMG and checksum to a prerelease.
- For a trusted downloadable binary release, install a Developer ID Application identity and configure an Apple notary profile.
