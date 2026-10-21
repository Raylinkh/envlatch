import Foundation
import Testing
@testable import EnvLatchCore

@Suite("Production transfer terminal consent", .serialized)
struct TransferTerminalConsentTests {
    @available(macOS 14.0, *)
    @Test(.enabled(if: ProcessInfo.processInfo.environment["ENVLATCH_TRANSFER_TERMINAL_TEST"] != nil))
    func terminalConsentNative() throws {
        let environment = ProcessInfo.processInfo.environment
        let mode = try #require(environment["ENVLATCH_TRANSFER_TERMINAL_TEST"])
        if mode == "no-tty" {
            #expect(throws: TransferError.consentRequired) { try TransferTerminalConsent.requireTerminal() }
            let secrets = TerminalNoValueStore()
            let groups = LaunchProfileStore(fileURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("envlatch-unused-terminal-test-\(UUID()).json"))
            let cli = TransferCLI(secrets: secrets, groups: groups, output: { _ in })
            #expect(throws: TransferError.consentRequired) {
                try cli.run(.send(peer: "Synthetic Unpaired", name: "ENVLATCH_TERMINAL_TOKEN", operation: UUID()))
            }
            #expect(secrets.calls == 0)
            print("terminal_no_tty_refused_before_values=true")
            return
        }
        let expected = environment["ENVLATCH_TRANSFER_TERMINAL_EXPECT_APPROVED"] == "true"
        let source = TransferIdentity()
        let target = TransferIdentity()
        let peer = try TransferPeer(name: "Synthetic Terminal Peer", publicKey: mode == "receive" ? source.publicKey : target.publicKey,
            address: "100.64.0.2")
        let approved: Bool
        if mode == "trust" {
            approved = try TransferTerminalConsent.approveTrust(peer)
        } else {
            #expect(mode == "send" || mode == "receive")
            let binding = try TransferBinding(operationID: UUID(uuidString: "901B3780-B39D-4DB5-814B-D05833D0B9FC")!,
                credentialName: "ENVLATCH_TERMINAL_TOKEN", sourceFingerprint: source.fingerprint,
                targetFingerprint: target.fingerprint)
            let request = TransferConsentRequest(direction: mode == "send" ? .send : .receive,
                binding: binding, peer: peer)
            approved = try TransferTerminalConsent.approveTransfer(request)
        }
        #expect(approved == expected)
        print("terminal_exact_approval_matches_expected=true")
    }
}

private final class TerminalNoValueStore: TransferSecretStore {
    private(set) var calls = 0
    func contains(name: CredentialName) throws -> Bool { calls += 1; throw TransferError.invalidInput }
    func load(name: CredentialName) throws -> String { calls += 1; throw TransferError.invalidInput }
    func create(name: CredentialName, value: String) throws { calls += 1; throw TransferError.invalidInput }
}
