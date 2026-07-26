<p align="center">
  <img src="Resources/AppIcon.png" width="88" alt="EnvLatch app icon">
</p>

<h1 align="center">EnvLatch — One macOS Keychain for every local agent</h1>

<p align="center">
  Store API keys once. Launch any local agent, SDK, script, test, or backend
  with exactly the saved keys it needs.
</p>

<p align="center">
  <a href="README.md"><strong>English</strong></a> ·
  <a href="README.zh-CN.md">简体中文</a>
</p>

<p align="center">
  <a href="https://github.com/Raylinkh/envlatch/releases"><img alt="Release" src="https://img.shields.io/github/v/release/Raylinkh/envlatch?include_prereleases&amp;style=flat-square&amp;color=725CFF"></a>
  <a href="https://github.com/Raylinkh/envlatch/actions/workflows/ci.yml"><img alt="CI" src="https://img.shields.io/github/actions/workflow/status/Raylinkh/envlatch/ci.yml?branch=main&amp;style=flat-square&amp;label=CI"></a>
  <img alt="macOS 13+" src="https://img.shields.io/badge/macOS-13%2B-111111?style=flat-square&amp;logo=apple">
  <img alt="Swift 6" src="https://img.shields.io/badge/Swift-6-F05138?style=flat-square&amp;logo=swift&amp;logoColor=white">
  <a href="LICENSE"><img alt="MIT License" src="https://img.shields.io/github/license/Raylinkh/envlatch?style=flat-square"></a>
  <a href="https://github.com/Raylinkh/envlatch/releases"><img alt="Release downloads" src="https://img.shields.io/github/downloads/Raylinkh/envlatch/total?style=flat-square&amp;label=downloads"></a>
</p>

![How EnvLatch replaces copied .env files with one macOS Keychain for every local agent](docs/assets/marketing/envlatch-hero.png)

```sh
envlatch run --using ANTHROPIC_API_KEY -- claude
envlatch run --using GITHUB_TOKEN -- gh auth status
envlatch run --using "Backend" -- npm test
```

The launched process receives ordinary environment variables, so existing code
keeps working as if the values came from a `.env` file. No EnvLatch SDK,
provider-specific command, proxy, or code change is required.

## Why EnvLatch

- **One command for every provider and tool.** Use a saved key by name or an
  optional key group; neither selects a hard-coded provider integration.
- **Multiple keys without broad exposure.** A key group contains the exact keys
  one command needs, while unselected EnvLatch keys are not read from Keychain.
- **Endpoint-compatible.** Per-key metadata can map a saved credential to the
  variable and base URL expected by Anthropic-, OpenAI-, or generic clients.
- **Agent-friendly without revealing values.** The bundled portable skill
  teaches any agent or host to inspect non-secret key and group names and wrap
  its normal command.
- **Native and local.** Values stay in the non-synchronizing macOS default
  Keychain. There is no server, account, sync layer, or custom cryptography.

## Install from source

Requirements: macOS 13 or newer and Xcode 16 or a Swift 6 toolchain.

```sh
git clone https://github.com/Raylinkh/envlatch.git
cd envlatch
./scripts/install.sh
open "$HOME/Applications/EnvLatch.app"
```

The installer:

- builds `EnvLatch.app` and installs it in `~/Applications`;
- creates `~/.local/bin/envlatch` as a symlink to the executable inside the app;
- installs one canonical skill at `~/.agents/skills/envlatch`;
- adds discovery links for Codex, Claude Code, and Gemini CLI.

Those agent links are conveniences, not an allowlist. Existing EnvLatch or
legacy AgentKeyring install paths are moved to timestamped backups.

Source builds are ad-hoc signed by default. That is suitable for local source
installation, but a rebuild may cause macOS to request Keychain authorization
again. See [Binary releases](#binary-releases) for the trusted distribution
boundary.

## Quick start

1. Open EnvLatch and choose **Add Key**.
2. Save a credential-shaped environment name such as `OPENAI_API_KEY`,
   `ANTHROPIC_API_KEY`, `GITHUB_TOKEN`, or `AWS_SECRET_ACCESS_KEY`.
3. If a client uses a compatible API at a custom endpoint, enable **Endpoint
   profile** and set its contract, base URL, and target credential variable.
4. Launch the normal command using the saved key name:

```sh
envlatch run --using OPENAI_API_KEY -- python3 server.py
```

5. Only when one command needs several keys, expand **Key groups**, choose
   **New Key Group**, and select the exact keys it needs:

```sh
envlatch run --using "Backend" -- python3 server.py
```

For example, the optional `Backend` group can select both `OPENAI_API_KEY` and
`GITHUB_TOKEN`. Python, Node, Swift, shell commands, and their SDKs read those
variables normally:

```python
import os

openai_key = os.environ["OPENAI_API_KEY"]
github_token = os.environ["GITHUB_TOKEN"]
```

EnvLatch replaces itself with the target executable using `execve`; it does not
invoke a shell or interpolate the arguments.

## Endpoint metadata

Endpoint metadata belongs to one saved key and never contains its value. It can
record:

- a display label;
- API contract (`Anthropic`, `OpenAI Chat Completions`, `OpenAI Responses`, or
  `Gemini`);
- HTTPS base URL with no query or fragment, with plain HTTP allowed only for
  loopback development;
- the credential variable expected by the target client.

A saved key can therefore remain `MINIMAX_API_KEY` while an Anthropic-compatible
client receives the same value as `ANTHROPIC_AUTH_TOKEN` plus the configured
`ANTHROPIC_BASE_URL`. Selecting that saved key directly—or including it in an
optional key group—makes those bindings available to the command.

EnvLatch validates the entire selection before reading any value. It
rejects missing keys, two sources targeting the same credential variable, and
conflicting contract configuration rather than choosing a last writer.

## Agent and host setup

Pairing is optional, one-time setup status—not authorization. Any agent or host
can provide its own display name:

```sh
envlatch pair "My build agent"
envlatch doctor
envlatch help
envlatch groups
```

The GUI includes a copyable setup prompt with those commands and the
least-privilege launch rule. The installed skill uses a saved key name directly
and asks for an optional key group only when a command needs several keys; it
must not silently fall back to broad access.

Safe inspection commands never read secret values:

```sh
envlatch list
envlatch groups
envlatch doctor
envlatch version
envlatch help
```

`envlatch run -- <command>` remains an explicit compatibility mode that exposes
every saved key to the launched process. Prefer `run --using`.

## Security boundary

EnvLatch reduces accidental credential leakage into repositories, `.env`
files, shell profiles, terminal history, command arguments, and its own logs.
It deliberately has no reveal, clipboard, export, `eval`, or `.env` command.

Environment injection is not secret isolation. A launched process and its
descendants can read every variable selected for that launch, and crash or
debug tooling may expose process memory. EnvLatch does not sandbox a malicious
agent or dependency. Use scoped keys and provider-side spending limits.

EnvLatch preserves the caller's inherited environment. It prevents unselected
EnvLatch Keychain items from being read, but it does not scrub credentials that
were already exported by the parent shell or launcher. Start from a clean
environment when inherited variables are also in scope.

Credential names must be uppercase POSIX variable names with a recognized
credential suffix. Loader-control names beginning with `DYLD_` or `LD_` are
rejected. Executables and symlinks are fully resolved and validated before
Keychain values are read.

The rename to EnvLatch intentionally retains the internal Keychain service
`dev.agentkeyring.secrets` and Application Support directory `AgentKeyring`.
This is a compatibility decision: existing values remain in one store and are
not copied during migration. See [SECURITY.md](SECURITY.md) for the full
boundary and reporting process.

## Development

```sh
swift test
./scripts/build-app.sh
dist/EnvLatch.app/Contents/MacOS/EnvLatch --version
```

The accepted behavior and release proof contract is in [SPEC.md](SPEC.md).
Current evidence and its limits are recorded in
[VERIFICATION.md](VERIFICATION.md).

GitHub Actions runs the test suite, validates scripts and bundle metadata,
builds the app, and verifies its structural code signature.

## Binary releases

### Unsigned preview

The GitHub `v0.1.0` pre-release includes an explicitly labeled, ad-hoc-signed
arm64 DMG and adjacent SHA-256 checksum. It is a convenience build for testers,
not an Apple-verified distribution. Gatekeeper will require **Privacy &
Security → Open Anyway** for the installer and may require it again for the
app.

Download both release assets and verify before mounting:

```sh
shasum -a 256 -c EnvLatch-0.1.0-macos-arm64-unsigned.dmg.sha256
```

The DMG contains `Install EnvLatch.command`, which transactionally installs the
app under `~/Applications`, the CLI under `~/.local/bin`, and the shared skill
under `~/.agents/skills`. Only use Open Anyway for a checksum-verified asset
downloaded from the official EnvLatch release.

### Notarized release

No friction-free downloadable binary is claimed until it has been Developer ID
signed, notarized by Apple, stapled, and assessed by Gatekeeper. A maintainer
with those credentials can prepare one with:

```sh
ENVLATCH_CODESIGN_IDENTITY="Developer ID Application: Name (TEAMID)" \
ENVLATCH_NOTARY_PROFILE="envlatch-notary" \
./scripts/package-release.sh
```

The script emits a notarized zip and SHA-256 checksum under `dist/`. The
unsigned DMG and source install remain preview distribution paths until that
receipt exists.

## License

[MIT](LICENSE)
