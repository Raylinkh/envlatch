import CryptoKit
import Foundation
import Testing
@testable import EnvLatchCore

@Suite("Authenticated selected-key transfer sessions", .serialized)
struct TransferSessionTests {
    @available(macOS 14.0, *)
    @Test func copiesOnlySelectedBytesThroughAuthenticatedFrames() throws {
        let fixture = try TransferFixture()
        defer { fixture.cleanup() }
        let result = fixture.exchange()
        let sent = try result.source.get()
        let received = try result.target.get()
        #expect(sent.state == .committed)
        #expect(received == sent)
        #expect(sent.binding == fixture.binding)
        #expect(fixture.sourceStore.loadCount == 1)
        #expect(fixture.sourceStore.createCount == 0)
        #expect(fixture.targetStore.createCount == 1)
        #expect(fixture.targetStore.matches(name: fixture.name, value: TransferFixture.sentinel))
        #expect(fixture.sourceStore.matches(name: fixture.name, value: TransferFixture.sentinel))
        #expect(!fixture.targetStore.has(name: fixture.unselected))
        #expect(fixture.sourceConsents.requests.count == 1)
        #expect(fixture.targetConsents.requests.count == 1)
        #expect(fixture.sourceConsents.requests.first?.binding == fixture.binding)
        #expect(fixture.targetConsents.requests.first?.binding == fixture.binding)
        #expect(!fixture.framesContainSentinel)
        #expect(try fixture.metadataContainsNoSentinel())
    }

    @available(macOS 14.0, *)
    @Test(arguments: [true, false])
    func cancellationBeforeDeliveryLeavesBothVaultsUnchanged(cancelSource: Bool) throws {
        let fixture = try TransferFixture()
        defer { fixture.cleanup() }
        if cancelSource { fixture.sourceConsents.approve = false }
        else { fixture.targetConsents.approve = false }
        let result = fixture.exchange()
        #expect(result.source.isFailure)
        #expect(result.target.isFailure)
        #expect(fixture.sourceStore.loadCount == 0)
        #expect(fixture.targetStore.createCount == 0)
        #expect(fixture.sourceStore.matches(name: fixture.name, value: TransferFixture.sentinel))
        #expect(!fixture.targetStore.has(name: fixture.name))
    }

    @available(macOS 14.0, *)
    @Test func existingTargetAndGroupCollisionRefuseBeforeSourceRead() throws {
        for groupCollision in [false, true] {
            let fixture = try TransferFixture()
            defer { fixture.cleanup() }
            if groupCollision { fixture.groups = [fixture.name.rawValue.lowercased()] }
            else { fixture.targetStore.seed(name: fixture.name, value: "public-existing-target-fixture") }
            let result = fixture.exchange()
            #expect(fixture.sourceStore.loadCount == 0)
            #expect(fixture.targetStore.createCount == 0)
            #expect(fixture.sourceStore.matches(name: fixture.name, value: TransferFixture.sentinel))
            if !groupCollision {
                #expect(fixture.targetStore.matches(name: fixture.name, value: "public-existing-target-fixture"))
            }
            let record = try result.target.get()
            #expect(record.state == .rejected)
            #expect(record.rejection == (groupCollision ? .groupConflict : .collision))
            #expect(try result.source.get() == record)
        }
    }

    @available(macOS 14.0, *)
    @Test func groupStoreFailureFailsClosed() throws {
        let fixture = try TransferFixture()
        defer { fixture.cleanup() }
        fixture.failGroupRead = true
        let result = fixture.exchange()
        #expect(result.source.isFailure)
        #expect(result.target.isFailure)
        #expect(fixture.sourceStore.loadCount == 0)
        #expect(fixture.targetStore.createCount == 0)
    }

    @available(macOS 14.0, *)
    @Test func committedReconnectReturnsOriginalReceiptWithoutConsentOrVaultAccess() throws {
        let fixture = try TransferFixture()
        defer { fixture.cleanup() }
        let first = fixture.exchange()
        let original = try first.source.get()
        _ = try first.target.get()
        fixture.sourceConsents.approve = false
        fixture.targetConsents.approve = false
        let second = fixture.exchange()
        #expect(try second.source.get() == original)
        #expect(try second.target.get() == original)
        #expect(fixture.sourceStore.loadCount == 1)
        #expect(fixture.targetStore.createCount == 1)
        #expect(fixture.sourceConsents.requests.count == 1)
        #expect(fixture.targetConsents.requests.count == 1)
    }

    @available(macOS 14.0, *)
    @Test func reservationWithoutTargetHistoryNeverStartsDeliveryOnReconnect() throws {
        let fixture = try TransferFixture()
        defer { fixture.cleanup() }
        try fixture.sourceMetadata.reserve(binding: fixture.binding)
        let result = fixture.exchange()
        #expect(result.source.isFailure || (try? result.source.get().status) == "unknown")
        #expect(fixture.sourceStore.loadCount == 0)
        #expect(fixture.targetStore.createCount == 0)
        #expect(try fixture.targetMetadata.status(binding: fixture.binding) == nil)
    }

    @available(macOS 14.0, *)
    @Test func deliveryInterruptedBeforeCommitStaysUnknownAndCannotReplay() throws {
        let fixture = try TransferFixture()
        defer { fixture.cleanup() }
        let interrupted = fixture.exchange(sourceFailSend: 2)
        #expect(interrupted.source.isFailure)
        #expect(interrupted.target.isFailure)
        #expect(fixture.targetStore.createCount == 0)
        #expect(try fixture.targetMetadata.status(binding: fixture.binding)?.status == "unknown")
        let reconnect = fixture.exchange()
        #expect(reconnect.source.isFailure || (try? reconnect.source.get().status) == "unknown")
        #expect(fixture.sourceStore.loadCount == 1)
        #expect(fixture.targetStore.createCount == 0)
    }

    @available(macOS 14.0, *)
    @Test func lostCommitReceiptReconcilesWithoutSecondReadOrCreate() throws {
        let fixture = try TransferFixture()
        defer { fixture.cleanup() }
        let interrupted = fixture.exchange(targetFailSend: 2)
        #expect(interrupted.source.isFailure)
        #expect(fixture.targetStore.createCount == 1)
        #expect(try fixture.targetMetadata.status(binding: fixture.binding)?.state == .committed)
        let reconnect = fixture.exchange()
        #expect(try reconnect.source.get().state == .committed)
        #expect(fixture.sourceStore.loadCount == 1)
        #expect(fixture.targetStore.createCount == 1)
    }

    @available(macOS 14.0, *)
    @Test func wrongPinnedSourceAndWrongNameCannotReleaseAnyValue() throws {
        for wrongName in [false, true] {
            let fixture = try TransferFixture()
            defer { fixture.cleanup() }
            let wrongIdentity = TransferIdentity()
            let wrongBinding = try TransferBinding(
                operationID: fixture.binding.operationID,
                credentialName: wrongName ? "ENVLATCH_WRONG_TOKEN" : fixture.name.rawValue,
                sourceFingerprint: wrongName ? fixture.sourceIdentity.fingerprint : wrongIdentity.fingerprint,
                targetFingerprint: fixture.targetIdentity.fingerprint
            )
            let result = fixture.exchange(targetBinding: wrongBinding)
            #expect(result.source.isFailure)
            #expect(result.target.isFailure)
            #expect(fixture.sourceStore.loadCount == 0)
            #expect(fixture.targetStore.createCount == 0)
        }
    }

    @available(macOS 14.0, *)
    @Test func tamperedOfferFailsAuthenticationBeforeReadOrWrite() throws {
        let fixture = try TransferFixture()
        defer { fixture.cleanup() }
        let result = fixture.exchange(tamperSourceSend: 1)
        #expect(result.source.isFailure)
        #expect(result.target.isFailure)
        #expect(fixture.sourceStore.loadCount == 0)
        #expect(fixture.targetStore.createCount == 0)
        #expect(!fixture.framesContainSentinel)
    }
}

@available(macOS 14.0, *)
private final class TransferFixture: @unchecked Sendable {
    static let sentinel = "public-synthetic-transfer-session-fixture-v1"
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("envlatch-session-\(UUID())")
    let sourceIdentity = TransferIdentity()
    let targetIdentity = TransferIdentity()
    let name = try! CredentialName(validating: "ENVLATCH_TRANSFER_TOKEN")
    let unselected = try! CredentialName(validating: "ENVLATCH_UNSELECTED_TOKEN")
    let sourceStore = TransferMemorySecrets()
    let targetStore = TransferMemorySecrets()
    let sourceConsents = TransferConsentCapture()
    let targetConsents = TransferConsentCapture()
    let sourceMetadata: TransferMetadataStore
    let targetMetadata: TransferMetadataStore
    let sourcePeer: TransferPeer
    let targetPeer: TransferPeer
    let binding: TransferBinding
    var groups: [String] = []
    var failGroupRead = false
    var frames: [Data] = []

    init() throws {
        sourceMetadata = TransferMetadataStore(directoryURL: root.appendingPathComponent("source"))
        targetMetadata = TransferMetadataStore(directoryURL: root.appendingPathComponent("target"))
        sourcePeer = try TransferPeer(name: "Source Synthetic", publicKey: sourceIdentity.publicKey, address: "100.64.0.1")
        targetPeer = try TransferPeer(name: "Target Synthetic", publicKey: targetIdentity.publicKey, address: "100.64.0.2")
        binding = try TransferBinding(operationID: UUID(), credentialName: name.rawValue,
            sourceFingerprint: sourceIdentity.fingerprint, targetFingerprint: targetIdentity.fingerprint)
        try sourceMetadata.pin(peer: targetPeer)
        try targetMetadata.pin(peer: sourcePeer)
        sourceStore.seed(name: name, value: Self.sentinel)
        sourceStore.seed(name: unselected, value: "public-unselected-transfer-fixture")
    }

    func cleanup() { try? FileManager.default.removeItem(at: root) }
    var framesContainSentinel: Bool { frames.contains { $0.range(of: Data(Self.sentinel.utf8)) != nil } }

    func metadataContainsNoSentinel() throws -> Bool {
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey]) else { return false }
        for case let path as URL in enumerator where try path.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
            if try Data(contentsOf: path).range(of: Data(Self.sentinel.utf8)) != nil { return false }
        }
        return true
    }

    func exchange(targetBinding: TransferBinding? = nil, sourceFailSend: Int? = nil,
                  targetFailSend: Int? = nil, tamperSourceSend: Int? = nil) -> TransferExchangeResult {
        let sourceSession = TransferSession(identity: sourceIdentity, peer: targetPeer,
            metadata: sourceMetadata, secrets: sourceStore, consent: sourceConsents.consent)
        let targetSession = TransferSession(identity: targetIdentity, peer: sourcePeer,
            metadata: targetMetadata, secrets: targetStore,
            groupNames: { if self.failGroupRead { throw TransferError.metadata }; return self.groups },
            consent: targetConsents.consent)
        let sourceInbox = TransferMailbox()
        let targetInbox = TransferMailbox()
        let sourceWire = TransferMemoryConnection(incoming: sourceInbox, outgoing: targetInbox,
            failSend: sourceFailSend, tamperSend: tamperSourceSend)
        let targetWire = TransferMemoryConnection(incoming: targetInbox, outgoing: sourceInbox,
            failSend: targetFailSend)
        let result = TransferResultBox()
        let action = TransferThreadAction {
            let outcome = Result { try targetSession.receive(binding: targetBinding ?? self.binding, connection: targetWire) }
            targetWire.close()
            result.finish(outcome)
        }
        Thread.detachNewThread { action.run() }
        let sourceResult = Result { try sourceSession.send(binding: binding, connection: sourceWire) }
        sourceWire.close()
        let targetResult = result.wait()
        frames += sourceWire.sentFrames + targetWire.sentFrames
        return TransferExchangeResult(source: sourceResult, target: targetResult)
    }
}

private struct TransferExchangeResult {
    let source: Result<TransferRecord, any Error>
    let target: Result<TransferRecord, any Error>
}

private extension Result {
    var isFailure: Bool { if case .failure = self { return true }; return false }
}

private final class TransferThreadAction: @unchecked Sendable {
    let run: () -> Void
    init(_ run: @escaping () -> Void) { self.run = run }
}

private final class TransferResultBox: @unchecked Sendable {
    private let condition = NSCondition()
    private var result: Result<TransferRecord, any Error>?
    func finish(_ result: Result<TransferRecord, any Error>) {
        condition.lock(); self.result = result; condition.broadcast(); condition.unlock()
    }
    func wait() -> Result<TransferRecord, any Error> {
        condition.lock()
        defer { condition.unlock() }
        let deadline = Date().addingTimeInterval(5)
        while result == nil {
            if !condition.wait(until: deadline) { return .failure(TransferError.timeout) }
        }
        return result!
    }
}

private final class TransferMailbox: @unchecked Sendable {
    let condition = NSCondition()
    var frames: [Data] = []
    var closed = false
}

private final class TransferMemoryConnection: TransferConnection, @unchecked Sendable {
    let incoming: TransferMailbox
    let outgoing: TransferMailbox
    let failSend: Int?
    let tamperSend: Int?
    private(set) var sentFrames: [Data] = []
    init(incoming: TransferMailbox, outgoing: TransferMailbox, failSend: Int? = nil, tamperSend: Int? = nil) {
        self.incoming = incoming; self.outgoing = outgoing
        self.failSend = failSend; self.tamperSend = tamperSend
    }
    func send(_ frame: Data) throws {
        let index = sentFrames.count + 1
        sentFrames.append(frame)
        if failSend == index { throw TransferError.transport }
        var delivered = frame
        if tamperSend == index, !delivered.isEmpty { delivered[delivered.count / 2] ^= 1 }
        outgoing.condition.lock()
        defer { outgoing.condition.unlock() }
        guard !outgoing.closed else { throw TransferError.transport }
        outgoing.frames.append(delivered)
        outgoing.condition.broadcast()
    }
    func receive() throws -> Data {
        incoming.condition.lock()
        defer { incoming.condition.unlock() }
        let deadline = Date().addingTimeInterval(3)
        while incoming.frames.isEmpty && !incoming.closed {
            if !incoming.condition.wait(until: deadline) { throw TransferError.timeout }
        }
        if !incoming.frames.isEmpty { return incoming.frames.removeFirst() }
        throw TransferError.transport
    }
    func close() {
        for mailbox in [incoming, outgoing] {
            mailbox.condition.lock(); mailbox.closed = true
            mailbox.condition.broadcast(); mailbox.condition.unlock()
        }
    }
}

private final class TransferConsentCapture: @unchecked Sendable {
    var approve = true
    private(set) var requests: [TransferConsentRequest] = []
    func consent(_ request: TransferConsentRequest) -> Bool { requests.append(request); return approve }
}

private final class TransferMemorySecrets: TransferSecretStore, @unchecked Sendable {
    private var values: [CredentialName: String] = [:]
    private(set) var loadCount = 0
    private(set) var createCount = 0
    func seed(name: CredentialName, value: String) { values[name] = value }
    func has(name: CredentialName) -> Bool { values[name] != nil }
    func matches(name: CredentialName, value: String) -> Bool { values[name] == value }
    func contains(name: CredentialName) -> Bool { has(name: name) }
    func load(name: CredentialName) throws -> String {
        loadCount += 1
        guard let value = values[name] else { throw TransferError.invalidInput }
        return value
    }
    func create(name: CredentialName, value: String) throws {
        guard values[name] == nil else { throw TransferError.collision }
        createCount += 1; values[name] = value
    }
}
