# AgentKeyring

AgentKeyring is a small native macOS utility for storing local AI-provider API keys once and releasing them only to a command you explicitly launch. Values live in macOS Keychain, not project `.env` files, shell startup files, command arguments, or AgentKeyring logs.

The GUI adds, replaces, lists, and deletes keys. An optional endpoint profile stores the provider label, API contract, base URL, and target credential environment name beside the Keychain reference—never the secret value. Every provider and tool still uses the same CLI:

```sh
agent-keyring run -- <command> [args...]
agent-keyring run --using <profile-name> -- <command> [args...]
```

## Install

```sh
./scripts/install.sh
open "$HOME/Applications/AgentKeyring.app"
```

The installer builds a release app in `dist/`, copies it to `~/Applications`, creates `~/.local/bin/agent-keyring`, installs one canonical Agent Skills artifact at `~/.agents/skills/agent-keyring`, and adds discovery links for Codex, Claude Code, and Gemini CLI. Those links are conveniences, not an allowlist. Any agent or host can register its own display name with `agent-keyring pair <name>`. Existing paths are moved to timestamped backups rather than deleted.

For a stable Keychain identity across rebuilds, provide a signing identity:

```sh
AGENT_KEYRING_CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./scripts/install.sh
```

Without one, the app is ad-hoc signed. It works locally, but macOS may ask you to reauthorize Keychain access after an upgrade changes the binary signature.

## Use

1. Open AgentKeyring and choose **Add Key**.
2. Enter a credential-shaped environment name such as `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `GITHUB_TOKEN`, or `AWS_SECRET_ACCESS_KEY`.
3. Paste the value. Optionally enable **Endpoint profile** and enter a provider/profile name, API contract, base URL, and the credential environment name expected by the target client.
4. Save, then use the same wrapper for every provider. A profiled launch is `agent-keyring run --using "MiniMax China" -- claude`; an unprofiled launch is `agent-keyring run -- make test`.

For the saved MiniMax key used in this project, the Claude Code profile is:

```text
Provider / profile: MiniMax China
API contract: Anthropic
API base URL: https://api.minimaxi.com/anthropic
Expose this key as: ANTHROPIC_AUTH_TOKEN
```

The contract derives `ANTHROPIC_BASE_URL`; the editable credential binding handles the fact that clients may expect different auth variable names. The same source Keychain item is not duplicated.

The paired `agent-keyring` skill teaches future agents to use this wrapper automatically when a command needs a saved credential. It never reveals a value to agent context.

Safe inspection never reads values:

```sh
agent-keyring list
agent-keyring profiles
agent-keyring doctor
agent-keyring help
agent-keyring pair "My agent or host"
```

Supported names are uppercase POSIX variables ending in `_API_KEY`, `_TOKEN`, `_SECRET`, `_PASSWORD`, `_ACCESS_KEY`, `_PRIVATE_KEY`, or `_CREDENTIAL`. Loader-control names beginning with `DYLD_` or `LD_` are rejected. This prevents a saved credential from changing command lookup or dynamic loading.

## Security boundary

AgentKeyring protects keys at rest and reduces accidental leakage into repositories, shell history, and logs. It deliberately has no value-reveal command, `.env` export, `eval` output, sync service, or shell interpolation.

Environment injection is not secret isolation. A profiled launch exposes its one referenced Keychain value under the saved name and configured client binding; an unprofiled launch exposes every saved key. The launched process and its descendants can read what was injected, and crash/debug tooling may expose process memory. Use provider-side spending limits and scoped keys. AgentKeyring does not sandbox a malicious agent or dependency.

Endpoint profiles and named-host registrations are non-secret JSON metadata under `~/Library/Application Support/AgentKeyring/` with user-only file permissions. They may contain provider labels and URLs, but never credential values.

V1 uses the normal non-synchronizing login Keychain with an explicit application-only ACL and is not App-Sandboxed because its job is to replace itself with arbitrary local tools. The CLI resolves a program against the caller's inherited `PATH` before reading credentials, then uses `execve` directly with the original arguments; it never invokes `/bin/sh`.

## Development

```sh
swift test
./scripts/build-app.sh
```

The accepted behavior and proof contract is in [SPEC.md](SPEC.md).
