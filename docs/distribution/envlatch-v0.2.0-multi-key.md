# EnvLatch v0.2.0 distribution copy

Status: ready for the GitHub v0.2.0 release; outbound community posting remains
unpublished.

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

Source and unsigned macOS preview:

https://github.com/Raylinkh/envlatch/releases/tag/v0.2.0

The preview is ad-hoc signed and not notarized. Verify its SHA-256 checksum and
expect macOS Privacy & Security → Open Anyway.
