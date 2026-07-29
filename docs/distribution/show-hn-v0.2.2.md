# Show HN launch — EnvLatch v0.2.2

## Status

Prepared for publication on 2026-07-29.

## Submission

Title:

> Show HN: EnvLatch – Keep API keys in macOS Keychain for local agents

URL:

> https://github.com/Raylinkh/envlatch

## First comment

Hi HN, I built EnvLatch because I was copying the same provider keys between
`.env` files whenever I switched between Claude, Codex, Cursor, scripts, SDKs,
and local backends.

EnvLatch stores values in macOS Keychain and launches an ordinary command with
only the named credentials as environment variables:

```sh
envlatch run --using OPENAI_API_KEY --using GITHUB_TOKEN -- npm test
```

Existing SDKs continue reading normal environment variables; there is no
EnvLatch SDK, proxy, provider integration, or code change. For repeated
combinations, key groups persist names only—the values are still read from
Keychain only when an explicit command is launched. Any agent or host can
record one-time pairing/setup status, but pairing is not authorization.

The security boundary is intentionally narrow: the launched process and its
descendants can read the selected variables, so EnvLatch reduces `.env` sprawl
and accidental copying but is not a sandbox or egress proxy.

v0.2.2 is MIT-licensed and the arm64 DMG/ZIP is Developer ID signed, notarized,
stapled, and available without an account. I would especially appreciate
feedback on the CLI/GUI split and which macOS agent hosts or tools should be
tested next.

## Channel rule

Do not ask anyone to upvote. Respond to technical questions with the exact
security boundary and current product behavior.

## Publication receipt

- Submission URL: pending
- First comment URL: pending
- Initial response: pending
