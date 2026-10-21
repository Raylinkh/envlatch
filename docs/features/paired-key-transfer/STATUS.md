# Paired Mac key transfer

## Current decision — 2026-10-21

Requested in owner-authorized Hub1118/1120 handoff; implementation authorized through a draft PR only. Base: `ff8b1754f8c28e3d5d65cf2833f5570af58fa03b`. Branch: `codex/paired-key-transfer`.

Coordinator decisions for this bounded slice: **copy only**, **create only**, **one saved key per operation**, **one-shot CLI receiver**, no persistent daemon. Source deletion and target overwrite are excluded. Existing agent-name `pair` records are display/setup metadata and confer no transfer authority. Transfer requires macOS 14+; existing local launch retains macOS 13 support. This is product work within the requested feature, with no scheduler, broker, agent runtime or process framework work.

### Contract and placement

1. Each Mac creates a separate non-synchronizing Keychain identity. Only its public key/fingerprint can be displayed. Users compare the complete SHA-256 public fingerprints through a trusted independent path and explicitly approve each named peer locally. A peer registry holds public keys and tailnet endpoints only. Replacing trust is refused in this slice.
2. The target starts a bounded receive command binding the exact peer, saved name and operation UUID, with explicit local approval. The source selects that same peer/name/operation and explicitly approves sending. Network reachability is not approval. Production consent uses the controlling terminal, fails closed without one, and has no auto-accept option.
3. Apple CryptoKit authenticated HPKE (RFC 9180) encrypts/authenticates envelopes in both directions. The platform owns key agreement, derivation and AEAD. Protocol version, kind, operation, peer identities, exact saved name and fresh target challenge bind the exchange. Source secret loading follows an authenticated approved challenge. No hand-written cipher/KDF/handshake or dependency is added.
4. Core owns protocol decisions; a bounded TCP adapter owns framing, deadlines and socket cleanup; KeychainSecretStore owns atomic create-only credential insertion. Peer/receipt metadata has a separate transfer store. CLI owns input and human consent. Direction: CLI -> transfer core -> CryptoKit / Security / Darwin.
5. Target persists a non-secret reserved operation before accepting value delivery. Replay cannot execute a reserved operation again. A successful Keychain create is followed by a durable committed receipt. Failure between commit and receipt is **unknown**, never reported as failure or retried as a replacement. Status is non-secret and binds the original name/peers/operation. Duplicate committed operations return the original receipt without a new source read or target write. A collision refuses the transfer and preserves both values.
6. Only credential bytes and their saved name transfer. Endpoint profiles, key groups, accounts, billing, agent setup and other vault entries do not transfer. Values stay in EnvLatch process memory and encrypted network frames until target Keychain insertion. No value is logged, printed, passed in argv, copied to clipboard, written to a temp file, or returned to an agent. This does not isolate a launched child's selected environment from that child or malicious local processes.

### Acceptance and ownership

| Input / real action | Independently observable output | Owner |
| --- | --- | --- |
| Two actual Macs, isolated synthetic Keychain services; pin both public identities; approve exact source/target/name; send selected key | Authenticated committed receipt; target selected-key child returns exact-match boolean; unselected absent; source unchanged | Independent test owner |
| Wrong/unpaired peer, target, name, challenge, operation or tampered frame | Refusal before value read/write; no echoed data | Independent test owner |
| Cancelled consent, existing-name collision, malformed/oversize frame | No overwrite, no source mutation, bounded non-secret error | Independent test owner |
| Duplicate/reconnect, interruption before commit, response lost after commit, receiver restart | At most one target create; committed or honest unknown status; no automatic resend/overwrite | Independent test owner |
| Existing local `run --using` and full regression suite | Existing selected-key behavior remains intact | Independent test owner + coordinator rerun |
| Exact assembled source commit | Independent Opus security/code review and green existing CI | Opus reviewer + coordinator |

Production implementer owns only `Sources/` and required Package.swift wiring. Test owner owns `Tests/` and synthetic acceptance scripts. Coordinator owns docs, integration, commits, PR and final rerun. Original untracked marketing paths remain untouched. No real credential may be read, transferred, modified or queried for acceptance. SSH alias `studio` is authorized only for scoped source/build and isolated synthetic proof; no service/cache/live-agent changes.

Runtime readiness: local Swift and existing 348 MB `.build` cache available; coordinator owns scheduling, test owner is the only initial build/test writer. Studio SSH responds as `/Users/jayden`, arm64 macOS 26.5.1 with Swift. Local tailnet address `100.102.186.35`; Studio `100.85.4.100`. Studio checkout absent at the expected local-user path; an isolated task-owned source tree/cache must be created and recorded. Protocol/test API is frozen before broad implementation. Native proof owner is the independent test owner; separate CLI consent and packaged-app acceptance stay explicit.

### Evidence / status

- Design checkpoint: native authenticated HPKE selected over TLS certificate bootstrap and custom encryption. [Apple HPKE](https://developer.apple.com/documentation/cryptokit/hpke), [authenticated sender](https://developer.apple.com/documentation/cryptokit/hpke/sender/init(recipientkey:ciphersuite:info:authenticatedby:)), [authenticated recipient](https://developer.apple.com/documentation/cryptokit/hpke/recipient/init(privatekey:ciphersuite:info:encapsulatedkey:authenticatedby:)) (checked 2026-10-21).
- Baseline: `swift test --no-parallel` exit 0; 68 tests across 18 suites on `c18a5809dc7a3b67837016cf51a02d47dfe6183a`. Existing real-Keychain cases use isolated `dev.envlatch.tests.*` services. Evidence: `/private/tmp/envlatch-transfer-tests-01a15f0a/baseline.log` and `baseline-manifest.json` (manifest SHA-256 `00f904f91434333d85c423e825734edde6e5604234e3b7ac796a3546f258e644`).
- Implementation: in progress. New source tests: pending. Genuine two-device proof: pending. Exact-head Opus review: pending. CI: pending.
- Draft PR requested explicitly. No tag, release, signing/notarization, installed app update or publication authorized. Ray holds release.
- Build ownership: reuse local primary `.build` (348 MB before work); only the current lease holder may build. Remote root `/Users/jayden/Library/Caches/EnvLatchTransfer-01a15f0a` was created exclusively for this task, owner marker is this chat ID, initial size 4 KB. Coordinator owns remote cleanup after inactivity. Retain source/history and non-secret evidence.
