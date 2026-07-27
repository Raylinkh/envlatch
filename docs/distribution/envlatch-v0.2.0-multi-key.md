# EnvLatch v0.2.0 distribution copy

Status: GitHub v0.2.0 signed release prepared; outbound community posting
remains unpublished.

## Short announcement

EnvLatch v0.2.0 lets local agents launch a command with several Keychain-backed
API keys without first creating a group:

```sh
envlatch run \
  --using OPENAI_API_KEY \
  --using GITHUB_TOKEN \
  -- npm test
```

For combinations used repeatedly, any local agent or host can create a
non-secret named group:

```sh
envlatch groups create "Backend" \
  --using OPENAI_API_KEY \
  --using GITHUB_TOKEN
envlatch run --using "Backend" -- npm test
```

`groups create` accepts saved key names only. It never reads or prints values,
never replaces an existing group, and rejects missing keys or conflicting
endpoint bindings before writing metadata. Pairing remains optional setup
status—not authorization.

Source and signed, notarized macOS download:

https://github.com/Raylinkh/envlatch/releases/tag/v0.2.0

The recommended arm64 DMG and ZIP are Developer ID signed, Apple-notarized,
stapled, and Gatekeeper-accepted. Adjacent SHA-256 checksum files are included.
