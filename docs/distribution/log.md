# Distribution log

## 2026-07-27

- Public exposure: https://github.com/Raylinkh/envlatch
- Downloadable prerelease: https://github.com/Raylinkh/envlatch/releases/tag/v0.1.0
- Artifact: explicitly unsigned arm64 DMG plus adjacent SHA-256 checksum
- Proof: remote asset download verified; first public macOS CI run passed
- Prepared distribution artifact: screenshot-led Chinese Xiaohongshu carousel,
  caption, safety boundary, repository link, and hashtags in
  `docs/distribution/xiaohongshu-v0.1.0.md`
- Outbound distribution: not yet posted to an external community or audience
- Prepared v0.2.0 GitHub release/distribution artifact:
  `docs/distribution/envlatch-v0.2.0-multi-key.md`
- Superseded the unposted v0.1.0 Xiaohongshu copy because it described key
  groups as the only multi-key path
- Published v0.2.0 unsigned prerelease:
  https://github.com/Raylinkh/envlatch/releases/tag/v0.2.0
- Proof: public macOS CI run `30238334541` passed; both release assets were
  downloaded back and the DMG matched SHA-256
  `65e864d68afbb5e716d40772b027d0e480778cfd40cebf8f857054a8ddd8874b`
- Prepared signed and notarized v0.2.0 arm64 ZIP and DMG:
  - ZIP notarization `59bd69de-17a7-4d37-af46-f252724d8f20`
  - DMG notarization `36fdad12-d1c9-4d8c-ab85-8c13dcb018bf`
  - both notary logs report `Accepted`, status code `0`, and no issues
  - stapler, Gatekeeper, mounted payload, isolated install, and rollback checks
    passed locally
- Uploaded the signed ZIP, DMG, and adjacent checksums to v0.2.0; retained the
  explicitly named unsigned DMG as a legacy preview.
- Downloaded all four signed assets into a fresh directory and reran the full
  release verifier successfully.
- Promoted v0.2.0 from prerelease to the stable latest GitHub release:
  https://github.com/Raylinkh/envlatch/releases/tag/v0.2.0

## 2026-07-28

- Prepared a public README refresh around the real provider-aware SwiftUI
  dashboard rather than a decorative mockup.
- Captured the app from a DEBUG-only isolated synthetic vault containing
  OpenAI, Anthropic, OpenRouter, GitHub, and one reusable two-key group.
- Embedded the sanitized capture in both English and Chinese READMEs.
- Bundled pinned real provider logos locally; EnvLatch still makes no provider
  or CDN request at runtime.
- Source candidate:
  `514e5c12c055678ae55b8c2418c47aad0d2f907e`
- Public README exposure reached `main` at
  `a86aa7e298ea9c2fd6c047aec7ecfb4a53386099`.
- Public CI run `30289430656` passed all test, app-bundle, and unsigned-preview
  jobs.
- The public screenshot was downloaded back and matched SHA-256
  `19696e6da131919a1c4291918bb1fb409c09d8c6c7c84390a369a6e48c411a92`.
- Published the stable v0.2.1 GitHub release:
  https://github.com/Raylinkh/envlatch/releases/tag/v0.2.1
- Distribution artifact: release notes plus signed/notarized arm64 ZIP and DMG
  with adjacent SHA-256 checksums.
- Proof:
  - exact tag source `c24eccd5ef3cb913cf3423c2765c51d57f61a6e1`;
  - public CI run `30300332620` passed;
  - Apple accepted ZIP submission `0cb62703-9892-4edc-85f3-ff1f285e8761`;
  - Apple accepted DMG submission `0cad7f06-a991-4f15-9138-7f853c084866`;
  - all four public assets were downloaded into a fresh directory and passed
    the full release verifier.
- Outbound response: GitHub README and release exposure only; no external
  community or social post yet.

## 2026-07-29

- Reproduced a host-sandbox contradiction: the same installed v0.2.1 CLI
  reported `saved_key_count=0` in the restricted agent process and
  `saved_key_count=4` with normal macOS Keychain access.
- Published the stable v0.2.2 GitHub release:
  https://github.com/Raylinkh/envlatch/releases/tag/v0.2.2
- Distribution artifact: patch release notes plus signed/notarized arm64 ZIP
  and DMG with adjacent SHA-256 checksums.
- Proof:
  - exact tag source `11de3c4aca5af087fc02f53379ede4153c07f061`;
  - public CI run `30422058632` passed;
  - Apple accepted ZIP submission `56b28a30-b222-41a7-ae08-e7e8a156b2d2`;
  - Apple accepted DMG submission `8d43911d-5943-4678-831c-7def604a2855`;
  - all four public assets were downloaded into a fresh directory and passed
    the full release verifier.
- Installed the downloaded public build locally. The installed CLI reports
  v0.2.2, sees four saved keys with normal Keychain access, and reports
  `cli_link=installed` and `agent_pairing=paired`.
- A least-privilege launch selected one saved key and passed a no-output local
  child assertion that its environment variable was present. No value was
  printed and no provider request was made.
- External community launch remains pending Hacker News account sign-in.
