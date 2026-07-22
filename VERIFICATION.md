# AgentKeyring verification record

Date: 2026-07-22
Platform: macOS arm64
Scope: installed native app, CLI symlink, portable skill, login Keychain, and direct process launch

## Structural checks

- `swift test`: 19 tests across 8 suites passed, including a real `execve` child-process probe.
- `quick_validate.py AgentSkill/agent-keyring`: `Skill is valid!`
- `zsh -n scripts/build-app.sh scripts/install.sh scripts/pair-agents.sh`: exit 0.
- `codesign --verify --deep --strict ~/Applications/AgentKeyring.app`: valid on disk and satisfies its designated requirement.
- Pairing dry-run executed twice against an isolated user-home root. Both runs resolved one CLI link and three agent links to one canonical skill, with no `previous-*` backup created on the unchanged second run.

## Installed pairing receipt

`agent-keyring doctor` reported:

```text
platform=macOS
keychain_attribute_query=reachable
cli_link=installed
agent_pairing=paired
pair_command='/Users/kehualin/Applications/AgentKeyring.app/Contents/Resources/pair-agents.sh'
```

The installed links resolved as follows:

```text
~/.local/bin/agent-keyring -> ~/Applications/AgentKeyring.app/Contents/MacOS/AgentKeyring
~/.codex/skills/agent-keyring -> ~/.agents/skills/agent-keyring
~/.claude/skills/agent-keyring -> ~/.agents/skills/agent-keyring
~/.gemini/skills/agent-keyring -> ~/.agents/skills/agent-keyring
```

`InstallationInspector` also verifies that each agent entry is a symlink to the canonical directory and that canonical `SKILL.md` bytes match the skill bundled inside the signed app. A stale or copied file reports `incomplete`.

## Installed GUI to CLI behavior

A high-entropy disposable value was generated in the desktop-control process and saved through the installed GUI as `AGENT_KEYRING_FINAL_TEST_TOKEN`. Only its SHA-256 digest was passed to the verifier. The installed CLI then replaced itself with the verifier and returned:

```text
exact_value=true
literal_argument=true
wrapper_exit=0
pid_preserved=true
```

The literal argument contained spaces, `*`, `[x]`, and `;`. It arrived unchanged. No shell command was constructed or invoked.

The repository, build tree, and captured runtime receipt were scanned for the disposable value:

```text
secret_leak_hits=0
```

## Keychain ACL negative proof

The disposable item was created with an explicit `kSecAttrAccess` ACL restricted to the installed AgentKeyring executable. A separately signed verifier disabled both legacy Keychain interaction and `LAContext` interaction before requesting the exact value. It returned:

```text
unrelated_read_denied=true
secret_data_returned=false
interaction_disabled=true
status=-25293
```

The application-only ACL uses macOS's deprecated file-based Keychain ACL APIs because a local ad-hoc build cannot use a stable data-protection access group without provisioning. This remains a compatibility risk; Developer ID signing is the supported stable-identity path.

## GUI inspection

The built and installed macOS windows were inspected through the accessibility tree. Verified states include secure Add Key fields, hidden saved values, provider-agnostic launch copy, textual paired status, destructive delete labeling, and the warning that every saved key is available to the launched process and its descendants.

## Cleanup state

The disposable Keychain items `AGENT_KEYRING_TEST_TOKEN`, `AGENT_KEYRING_ACL_TEST_TOKEN`, and `AGENT_KEYRING_FINAL_TEST_TOKEN` contain no real credentials. Their GUI deletion awaits the required irreversible-action confirmation.
