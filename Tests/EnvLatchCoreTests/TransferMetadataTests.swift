import Foundation
import Testing
@testable import EnvLatchCore

@Suite("Paired transfer metadata and create-only storage", .serialized)
struct TransferMetadataTests {
    @Test(arguments: ["100.64.0.0", "100.102.186.35", "100.127.255.255"])
    func peerConstructorAcceptsCanonicalNumericTailnetAddresses(_ address: String) throws {
        let peer = try TransferPeer(name: "Synthetic Studio", publicKey: TransferIdentity().publicKey,
                                    address: address)
        #expect(peer.address == address)
        #expect(peer.port == 49271)
    }

    @Test(arguments: [
        "", "studio", "studio.example.ts.net", "127.0.0.1", "0.0.0.0",
        "100.63.255.255", "100.128.0.0", "100.256.0.1", "100.64.0",
        "100.064.0.1", "100.64.00.1", "100.64.0.01", "+100.64.0.1",
        "100.64.0.1.", "100.64.0.1:49271", " 100.64.0.1", "100.64.0.1 ",
        "[fd7a:115c:a1e0::1]", "https://100.64.0.1",
    ])
    func peerConstructorRejectsNamesAndNoncanonicalOrOutsideAddresses(_ address: String) {
        #expect(throws: TransferError.invalidInput) {
            _ = try TransferPeer(name: "Synthetic Studio", publicKey: TransferIdentity().publicKey,
                                 address: address)
        }
    }

    @Test func peerConstructorRejectsInvalidIdentityPortAndDisplayName() {
        let key = TransferIdentity().publicKey
        for name in ["", "Synthetic\nStudio", "Synthetic\u{0000}Studio", String(repeating: "x", count: 81)] {
            #expect(throws: TransferError.invalidInput) {
                _ = try TransferPeer(name: name, publicKey: key, address: "100.64.0.1")
            }
        }
        for invalidKey in [Data(), Data(repeating: 0x41, count: 31), Data(repeating: 0x41, count: 33)] {
            #expect(throws: TransferError.invalidInput) {
                _ = try TransferPeer(name: "Synthetic Studio", publicKey: invalidKey, address: "100.64.0.1")
            }
        }
        #expect(throws: TransferError.invalidInput) {
            _ = try TransferPeer(name: "Synthetic Studio", publicKey: key, address: "100.64.0.1", port: 0)
        }
    }

    @Test func bindingRetainsExactNameOperationAndDistinctPeerIdentities() throws {
        let operation = UUID()
        let source = TransferIdentity().fingerprint
        let target = TransferIdentity().fingerprint
        let binding = try TransferBinding(operationID: operation, credentialName: "ENVLATCH_TRANSFER_TOKEN",
                                          sourceFingerprint: source, targetFingerprint: target)
        let reopened = try JSONDecoder().decode(TransferBinding.self, from: JSONEncoder().encode(binding))
        #expect(reopened == binding)
        #expect(reopened.operationID == operation)
        #expect(reopened.credentialName == "ENVLATCH_TRANSFER_TOKEN")
        #expect(reopened.sourceFingerprint == source)
        #expect(reopened.targetFingerprint == target)
        #expect(throws: TransferError.invalidInput) {
            _ = try TransferBinding(operationID: operation, credentialName: "ENVLATCH_TRANSFER_TOKEN",
                                    sourceFingerprint: source, targetFingerprint: source)
        }
        for invalidFingerprint in ["", String(repeating: "a", count: 63),
                                   String(repeating: "a", count: 65), String(repeating: "A", count: 64),
                                   String(repeating: "g", count: 64)] {
            #expect(throws: TransferError.invalidInput) {
                _ = try TransferBinding(operationID: operation, credentialName: "ENVLATCH_TRANSFER_TOKEN",
                                        sourceFingerprint: invalidFingerprint, targetFingerprint: target)
            }
        }
        for invalidName in ["envlatch_transfer_token", "ENVLATCH_TRANSFER", "DYLD_TEST_TOKEN"] {
            #expect(throws: (any Error).self) {
                _ = try TransferBinding(operationID: operation, credentialName: invalidName,
                                        sourceFingerprint: source, targetFingerprint: target)
            }
        }
    }

    @Test func peerPinsAreImmutableCaseInsensitiveBindingsToPublicIdentity() throws {
        let root = metadataDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let identity = TransferIdentity()
        let peer = try TransferPeer(name: "Synthetic Studio", publicKey: identity.publicKey, address: "100.64.0.1")
        let store = TransferMetadataStore(directoryURL: root)
        #expect(throws: TransferError.untrustedPeer) { try store.peer(named: peer.name) }
        try store.pin(peer: peer)
        let reopened = TransferMetadataStore(directoryURL: root)
        #expect(try reopened.peer(named: "SYNTHETIC STUDIO") == peer)
        #expect(throws: TransferError.trustAlreadyExists) { try reopened.pin(peer: peer) }
        let changed = try TransferPeer(name: "synthetic studio", publicKey: TransferIdentity().publicKey,
                                       address: "100.64.0.2", port: 49272)
        #expect(throws: TransferError.trustAlreadyExists) { try reopened.pin(peer: changed) }
        #expect(try reopened.peer(named: "synthetic studio") == peer)

        let alias = try TransferPeer(name: "Other Synthetic Alias", publicKey: identity.publicKey, address: "100.64.0.3")
        try reopened.pin(peer: alias)
        #expect(try reopened.peer(named: alias.name) == alias)
        #expect(try reopened.peer(named: alias.name).fingerprint == peer.fingerprint)
        #expect(throws: TransferError.untrustedPeer) { try reopened.peer(named: "Other Mac") }
    }

    @Test func reservationAndCommittedReceiptSurviveReopenWithoutReexecution() throws {
        let root = metadataDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let binding = try makeBinding()
        let store = TransferMetadataStore(directoryURL: root)
        #expect(try store.status(binding: binding) == nil)
        #expect(try store.reserve(binding: binding))
        let reopened = TransferMetadataStore(directoryURL: root)
        let reserved = try #require(try reopened.status(binding: binding))
        #expect(reserved.binding == binding)
        #expect(reserved.state == .reserved)
        #expect(reserved.status == "unknown")
        #expect(reserved.rejection == nil)
        #expect(try !reopened.reserve(binding: binding))
        let committed = TransferRecord(binding: binding, state: .committed)
        try reopened.finish(committed)
        let finalStore = TransferMetadataStore(directoryURL: root)
        #expect(try finalStore.status(binding: binding) == committed)
        #expect(try !finalStore.reserve(binding: binding))
        #expect(throws: TransferError.metadata) { try finalStore.finish(committed) }
        #expect(try finalStore.status(binding: binding) == committed)
    }

    @Test func sameOperationCannotBeReboundToAnotherKeyOrPeer() throws {
        let root = metadataDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let binding = try makeBinding()
        let store = TransferMetadataStore(directoryURL: root)
        #expect(try store.reserve(binding: binding))
        let changedName = try TransferBinding(operationID: binding.operationID, credentialName: "ENVLATCH_OTHER_TOKEN",
                                              sourceFingerprint: binding.sourceFingerprint,
                                              targetFingerprint: binding.targetFingerprint)
        let changedPeers = try TransferBinding(operationID: binding.operationID, credentialName: binding.credentialName,
                                               sourceFingerprint: binding.targetFingerprint,
                                               targetFingerprint: binding.sourceFingerprint)
        for changed in [changedName, changedPeers] {
            #expect(throws: TransferError.bindingMismatch) { try store.status(binding: changed) }
            #expect(throws: TransferError.bindingMismatch) { try store.reserve(binding: changed) }
            #expect(throws: TransferError.bindingMismatch) {
                try store.finish(TransferRecord(binding: changed, state: .committed))
            }
        }
        #expect(try store.status(binding: binding)?.state == .reserved)
    }

    @Test(arguments: [TransferRejection.collision, .groupConflict])
    func rejectionReceiptIsDurableAndCannotBeCommitted(_ reason: TransferRejection) throws {
        let root = metadataDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let binding = try makeBinding()
        let store = TransferMetadataStore(directoryURL: root)
        #expect(try store.reserve(binding: binding))
        let rejected = TransferRecord(binding: binding, state: .rejected, rejection: reason)
        try store.finish(rejected)
        let reopened = TransferMetadataStore(directoryURL: root)
        #expect(try reopened.status(binding: binding) == rejected)
        #expect(try !reopened.reserve(binding: binding))
        #expect(throws: TransferError.metadata) {
            try reopened.finish(TransferRecord(binding: binding, state: .committed))
        }
        #expect(try reopened.status(binding: binding) == rejected)
    }

    @Test func invalidFinalRecordsCannotCorruptAReservation() throws {
        let root = metadataDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let binding = try makeBinding()
        let store = TransferMetadataStore(directoryURL: root)
        #expect(throws: TransferError.metadata) {
            try store.finish(TransferRecord(binding: binding, state: .committed))
        }
        #expect(try store.reserve(binding: binding))
        for record in [TransferRecord(binding: binding, state: .reserved),
                       TransferRecord(binding: binding, state: .committed, rejection: .collision),
                       TransferRecord(binding: binding, state: .rejected)] {
            #expect(throws: TransferError.metadata) { try store.finish(record) }
            #expect(try store.status(binding: binding) == TransferRecord(binding: binding, state: .reserved))
        }
    }

    @Test(arguments: ["invalid-name", "same-peer", "invalid-fingerprint"])
    func decodedInvalidBindingCannotEnterTheJournal(_ mutation: String) throws {
        let root = metadataDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let binding = try makeBinding()
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(binding)) as? [String: Any])
        switch mutation {
        case "invalid-name": object["credentialName"] = "UNSAFE"
        case "same-peer": object["targetFingerprint"] = binding.sourceFingerprint
        case "invalid-fingerprint": object["sourceFingerprint"] = String(repeating: "A", count: 64)
        default: Issue.record("Unknown binding mutation")
        }
        let decoded = try JSONDecoder().decode(TransferBinding.self, from: JSONSerialization.data(withJSONObject: object))
        let store = TransferMetadataStore(directoryURL: root)
        #expect(throws: (any Error).self) { try store.reserve(binding: decoded) }
        #expect(throws: (any Error).self) { try store.status(binding: decoded) }
        #expect(throws: (any Error).self) { try store.finish(TransferRecord(binding: decoded, state: .committed)) }
        #expect(try store.status(binding: binding) == nil)
    }

    @Test(arguments: ["invalid-json", "empty", "oversized", "wrong-key", "wrong-name", "dns-address", "zero-port"])
    func malformedPersistedPeerFailsClosed(_ mutation: String) throws {
        let root = metadataDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let peer = try TransferPeer(name: "Synthetic Studio", publicKey: TransferIdentity().publicKey, address: "100.64.0.1")
        let store = TransferMetadataStore(directoryURL: root)
        try store.pin(peer: peer)
        let file = try metadataFile(in: root, prefix: "peer-")
        switch mutation {
        case "invalid-json": try replaceFile(Data("{".utf8), at: file)
        case "empty": try replaceFile(Data(), at: file)
        case "oversized": try replaceFile(Data(repeating: 0x20, count: 16_385), at: file)
        default:
            try rewriteJSON(at: file) { object in
                switch mutation {
                case "wrong-key": object["publicKey"] = Data(repeating: 0x41, count: 31).base64EncodedString()
                case "wrong-name": object["name"] = "Other Synthetic Mac"
                case "dns-address": object["address"] = "studio.example.ts.net"
                case "zero-port": object["port"] = 0
                default: Issue.record("Unknown peer mutation")
                }
            }
        }
        #expect(throws: (any Error).self) { try TransferMetadataStore(directoryURL: root).peer(named: peer.name) }
    }

    @Test(arguments: ["invalid-state", "committed-rejection", "missing-rejection", "changed-name", "changed-operation"])
    func malformedPersistedJournalCannotAuthorizeDelivery(_ mutation: String) throws {
        let root = metadataDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let binding = try makeBinding()
        let store = TransferMetadataStore(directoryURL: root)
        #expect(try store.reserve(binding: binding))
        let file = try metadataFile(in: root, prefix: "operation-")
        try rewriteJSON(at: file) { object in
            switch mutation {
            case "invalid-state": object["state"] = "accepted"
            case "committed-rejection":
                object["state"] = "committed"
                object["rejection"] = "collision"
            case "missing-rejection": object["state"] = "rejected"
            case "changed-name", "changed-operation":
                var storedBinding = try #require(object["binding"] as? [String: Any])
                if mutation == "changed-name" { storedBinding["credentialName"] = "ENVLATCH_OTHER_TOKEN" }
                else { storedBinding["operationID"] = UUID().uuidString }
                object["binding"] = storedBinding
            default: Issue.record("Unknown journal mutation")
            }
        }
        let reopened = TransferMetadataStore(directoryURL: root)
        #expect(throws: (any Error).self) { try reopened.status(binding: binding) }
        #expect(throws: (any Error).self) { try reopened.reserve(binding: binding) }
    }

    @Test func metadataCreatesPrivateDirectoryAndFilesAndRejectsUnsafeModes() throws {
        let root = metadataDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let peer = try TransferPeer(name: "Synthetic Studio", publicKey: TransferIdentity().publicKey, address: "100.64.0.1")
        let store = TransferMetadataStore(directoryURL: root)
        try store.pin(peer: peer)
        let file = try metadataFile(in: root, prefix: "peer-")
        #expect(try mode(of: root) == 0o700)
        #expect(try mode(of: file) == 0o600)
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: file.path)
        #expect(throws: TransferError.metadata) { try store.peer(named: peer.name) }
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
        #expect(try store.peer(named: peer.name) == peer)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: root.path)
        #expect(throws: TransferError.metadata) { try store.peer(named: peer.name) }
        #expect(throws: TransferError.metadata) { try store.reserve(binding: makeBinding()) }
    }

    @Test func symlinkedMetadataDirectoryAndPeerFileFailClosed() throws {
        let root = metadataDirectory()
        let link = metadataDirectory()
        defer {
            try? FileManager.default.removeItem(at: link)
            try? FileManager.default.removeItem(at: root)
        }
        let peer = try TransferPeer(name: "Synthetic Studio", publicKey: TransferIdentity().publicKey, address: "100.64.0.1")
        let store = TransferMetadataStore(directoryURL: root)
        try store.pin(peer: peer)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: root)
        #expect(throws: TransferError.metadata) {
            try TransferMetadataStore(directoryURL: link).peer(named: peer.name)
        }
        let file = try metadataFile(in: root, prefix: "peer-")
        let original = root.appendingPathComponent("original-public-peer.json")
        try FileManager.default.moveItem(at: file, to: original)
        try FileManager.default.createSymbolicLink(at: file, withDestinationURL: original)
        #expect(throws: TransferError.metadata) { try store.peer(named: peer.name) }
    }

    @Test func nativeCreateRefusesExistingTargetAndPreservesExactBytes() throws {
        let store = KeychainSecretStore(service: "dev.envlatch.transfer.tests.\(UUID().uuidString)")
        let selected = try CredentialName(validating: "ENVLATCH_TRANSFER_TOKEN")
        let unselected = try CredentialName(validating: "ENVLATCH_UNSELECTED_TOKEN")
        let original = "public-synthetic-\(UUID().uuidString)\n "
        let attempted = "public-synthetic-\(UUID().uuidString)"
        defer {
            try? store.delete(name: selected)
            try? store.delete(name: unselected)
        }

        #expect(try !store.contains(name: selected))
        try store.create(name: selected, value: original)
        #expect(try store.contains(name: selected))
        #expect(try !store.contains(name: unselected))
        #expect(throws: TransferError.collision) {
            try store.create(name: selected, value: attempted)
        }
        let preserved = try store.load(name: selected) == original
        #expect(preserved)
        #expect(try store.listNames() == [selected])
    }

    @Test func nativeConcurrentCreateHasOneWinnerWithoutReplacingItsValue() async throws {
        let service = "dev.envlatch.transfer.tests.\(UUID().uuidString)"
        let store = KeychainSecretStore(service: service)
        let name = try CredentialName(validating: "ENVLATCH_TRANSFER_TOKEN")
        defer { try? store.delete(name: name) }
        let candidates = (0..<4).map { "public-synthetic-\($0)-\(UUID().uuidString)" }
        let outcomes = await withTaskGroup(of: CreateAttempt.self, returning: [CreateAttempt].self) { group in
            for (index, value) in candidates.enumerated() {
                group.addTask {
                    do {
                        try KeychainSecretStore(service: service).create(name: name, value: value)
                        return CreateAttempt(index: index, result: .created)
                    } catch TransferError.collision {
                        return CreateAttempt(index: index, result: .collision)
                    } catch {
                        return CreateAttempt(index: index, result: .unexpectedFailure)
                    }
                }
            }
            var results: [CreateAttempt] = []
            for await outcome in group { results.append(outcome) }
            return results
        }
        let winners = outcomes.filter { $0.result == .created }
        #expect(winners.count == 1)
        #expect(outcomes.filter { $0.result == .collision }.count == 3)
        #expect(!outcomes.contains { $0.result == .unexpectedFailure })
        if let winner = winners.first {
            let preserved = try store.load(name: name) == candidates[winner.index]
            #expect(preserved)
        }
    }

    private struct CreateAttempt: Sendable {
        enum Result: Equatable, Sendable { case created, collision, unexpectedFailure }
        let index: Int
        let result: Result
    }

    private func metadataDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("envlatch-transfer-metadata-\(UUID().uuidString)",
                                                                     isDirectory: true)
    }

    private func makeBinding() throws -> TransferBinding {
        try TransferBinding(operationID: UUID(), credentialName: "ENVLATCH_TRANSFER_TOKEN",
                            sourceFingerprint: TransferIdentity().fingerprint,
                            targetFingerprint: TransferIdentity().fingerprint)
    }

    private func metadataFile(in root: URL, prefix: String) throws -> URL {
        let files = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix(prefix) }
        try #require(files.count == 1)
        return files[0]
    }

    private func rewriteJSON(at file: URL, mutate: (inout [String: Any]) throws -> Void) throws {
        var object = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
        try mutate(&object)
        try replaceFile(JSONSerialization.data(withJSONObject: object), at: file)
    }

    private func replaceFile(_ bytes: Data, at file: URL) throws {
        try bytes.write(to: file, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
    }

    private func mode(of file: URL) throws -> Int {
        let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
        return (try #require(attributes[.posixPermissions] as? NSNumber)).intValue & 0o777
    }
}
