import CryptoKit
import Foundation

// Every message is authenticated with the pinned sender key. The full operation
// and both nonces are inside the ciphertext; no unauthenticated routing fields
// decide whether a credential may be read or created.
enum TransferMessage: Codable {
    case offer(TransferBinding, sourceNonce: Data)
    case status(TransferBinding, sourceNonce: Data)
    case ready(TransferBinding, sourceNonce: Data, targetNonce: Data)
    case delivery(TransferBinding, sourceNonce: Data, targetNonce: Data, value: Data)
    case result(TransferRecord, sourceNonce: Data, targetNonce: Data?)
}

struct TransferEnvelope: Codable {
    let encapsulatedKey: Data
    let ciphertext: Data
}

@available(macOS 14.0, *)
public struct TransferSession {
    public static let maximumValueBytes = 65_536
    public static let maximumFrameBytes = 131_072
    private static let context = Data("EnvLatch paired-key-transfer v1 / authenticated HPKE".utf8)
    private let identity: TransferIdentity
    private let peer: TransferPeer
    private let metadata: TransferMetadataStore
    private let secrets: any TransferSecretStore
    private let groupNames: () throws -> [String]
    private let consent: (TransferConsentRequest) throws -> Bool

    public init(identity: TransferIdentity, peer: TransferPeer, metadata: TransferMetadataStore,
                secrets: any TransferSecretStore, groupNames: @escaping () throws -> [String] = { [] },
                consent: @escaping (TransferConsentRequest) throws -> Bool) {
        self.identity = identity
        self.peer = peer
        self.metadata = metadata
        self.secrets = secrets
        self.groupNames = groupNames
        self.consent = consent
    }

    public func send(binding: TransferBinding, connection: any TransferConnection) throws -> TransferRecord {
        defer { connection.close() }
        try validate(binding, sending: true)
        let existing = try metadata.status(binding: binding)
        if existing == nil {
            guard try consent(.init(direction: .send, binding: binding, peer: peer)) else { throw TransferError.denied }
        }
        let firstAttempt = existing == nil ? try metadata.reserve(binding: binding) : false
        let sourceNonce = randomNonce()
        let request: TransferMessage = firstAttempt
            ? .offer(binding, sourceNonce: sourceNonce) : .status(binding, sourceNonce: sourceNonce)
        try write(request, to: connection)
        switch try read(from: connection) {
        case .result(let record, let receivedNonce, nil):
            guard receivedNonce == sourceNonce else { throw TransferError.protocolViolation }
            return try accept(record, binding: binding)
        case .ready(let approved, let receivedNonce, let targetNonce):
            guard firstAttempt, approved == binding, receivedNonce == sourceNonce,
                  targetNonce.count == 32 else { throw TransferError.protocolViolation }
            // Authentication and both approvals precede the only source value read.
            let name = try CredentialName(validating: binding.credentialName)
            let value = try secrets.load(name: name)
            try CredentialName.validateValue(value)
            guard value.utf8.count <= Self.maximumValueBytes else { throw TransferError.frameTooLarge }
            do {
                try write(.delivery(binding, sourceNonce: sourceNonce, targetNonce: targetNonce,
                                    value: Data(value.utf8)), to: connection)
                guard case .result(let record, let resultSource, let resultTarget) = try read(from: connection),
                      resultSource == sourceNonce, resultTarget == targetNonce else {
                    throw TransferError.protocolViolation
                }
                return try accept(record, binding: binding)
            } catch {
                // A failed write/ACK cannot distinguish a remote commit from no commit.
                throw TransferError.outcomeUnknown
            }
        default: throw TransferError.protocolViolation
        }
    }

    public func receive(binding: TransferBinding, connection: any TransferConnection) throws -> TransferRecord {
        defer { connection.close() }
        try validate(binding, sending: false)
        let request = try read(from: connection)
        let sourceNonce: Data
        let statusOnly: Bool
        switch request {
        case .offer(let requested, let nonce):
            guard requested == binding else { throw TransferError.bindingMismatch }
            sourceNonce = nonce
            statusOnly = false
        case .status(let requested, let nonce):
            guard requested == binding else { throw TransferError.bindingMismatch }
            sourceNonce = nonce
            statusOnly = true
        default: throw TransferError.protocolViolation
        }
        guard sourceNonce.count == 32 else { throw TransferError.protocolViolation }
        if let record = try metadata.status(binding: binding) {
            try write(.result(record, sourceNonce: sourceNonce, targetNonce: nil), to: connection)
            return record
        }
        if statusOnly {
            let unknown = TransferRecord(binding: binding, state: .reserved)
            try write(.result(unknown, sourceNonce: sourceNonce, targetNonce: nil), to: connection)
            return unknown
        }
        guard try consent(.init(direction: .receive, binding: binding, peer: peer)) else { throw TransferError.denied }
        guard try metadata.reserve(binding: binding) else {
            let record = try metadata.status(binding: binding) ?? .init(binding: binding, state: .reserved)
            try write(.result(record, sourceNonce: sourceNonce, targetNonce: nil), to: connection)
            return record
        }
        let name = try CredentialName(validating: binding.credentialName)
        if try groupNames().contains(where: { $0.caseInsensitiveCompare(name.rawValue) == .orderedSame }) {
            return try reject(.groupConflict, binding: binding, sourceNonce: sourceNonce, connection: connection)
        }
        if try secrets.contains(name: name) {
            return try reject(.collision, binding: binding, sourceNonce: sourceNonce, connection: connection)
        }
        let targetNonce = randomNonce()
        try write(.ready(binding, sourceNonce: sourceNonce, targetNonce: targetNonce), to: connection)
        guard case .delivery(let delivered, let deliverySource, let deliveryTarget, let bytes) = try read(from: connection),
              delivered == binding, deliverySource == sourceNonce, deliveryTarget == targetNonce,
              bytes.count <= Self.maximumValueBytes, let value = String(data: bytes, encoding: .utf8) else {
            throw TransferError.protocolViolation
        }
        do { try CredentialName.validateValue(value) } catch { throw TransferError.protocolViolation }
        // A group could have appeared during approval/delivery. Refuse before insertion.
        if try groupNames().contains(where: { $0.caseInsensitiveCompare(name.rawValue) == .orderedSame }) {
            return try reject(.groupConflict, binding: binding, sourceNonce: sourceNonce,
                              targetNonce: targetNonce, connection: connection)
        }
        do { try secrets.create(name: name, value: value) }
        catch TransferError.collision {
            return try reject(.collision, binding: binding, sourceNonce: sourceNonce,
                              targetNonce: targetNonce, connection: connection)
        }
        // A crash or metadata failure here leaves reserved/unknown and cannot repeat insertion.
        let committed = TransferRecord(binding: binding, state: .committed)
        do { try metadata.finish(committed) } catch { throw TransferError.outcomeUnknown }
        do { try write(.result(committed, sourceNonce: sourceNonce, targetNonce: targetNonce), to: connection) }
        catch { return committed } // Durable receipt remains queryable after lost ACK.
        return committed
    }

    private func validate(_ binding: TransferBinding, sending: Bool) throws {
        _ = try TransferBinding(operationID: binding.operationID, credentialName: binding.credentialName,
                                sourceFingerprint: binding.sourceFingerprint, targetFingerprint: binding.targetFingerprint)
        let pinned = try metadata.peer(named: peer.name)
        guard pinned == peer else { throw TransferError.untrustedPeer }
        guard (sending ? binding.sourceFingerprint : binding.targetFingerprint) == identity.fingerprint,
              (sending ? binding.targetFingerprint : binding.sourceFingerprint) == peer.fingerprint else {
            throw TransferError.bindingMismatch
        }
    }

    private func accept(_ record: TransferRecord, binding: TransferBinding) throws -> TransferRecord {
        guard record.binding == binding,
              (record.state == .rejected) == (record.rejection != nil) else { throw TransferError.bindingMismatch }
        if record.state != .reserved {
            if let current = try metadata.status(binding: binding), current.state == .reserved {
                try metadata.finish(record)
            } else if try metadata.status(binding: binding) != record { throw TransferError.bindingMismatch }
        }
        return record
    }

    private func reject(_ reason: TransferRejection, binding: TransferBinding, sourceNonce: Data,
                        targetNonce: Data? = nil, connection: any TransferConnection) throws -> TransferRecord {
        let record = TransferRecord(binding: binding, state: .rejected, rejection: reason)
        try metadata.finish(record)
        try write(.result(record, sourceNonce: sourceNonce, targetNonce: targetNonce), to: connection)
        return record
    }

    private func randomNonce() -> Data {
        var generator = SystemRandomNumberGenerator()
        return Data((0..<32).map { _ in UInt8.random(in: .min ... .max, using: &generator) })
    }

    private func write(_ message: TransferMessage, to connection: any TransferConnection) throws {
        let bytes: Data
        do {
            let publicKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: peer.publicKey)
            var sender = try HPKE.Sender(recipientKey: publicKey, ciphersuite: .Curve25519_SHA256_ChachaPoly,
                                         info: Self.context, authenticatedBy: identity.privateKey)
            let ciphertext = try sender.seal(JSONEncoder().encode(message))
            bytes = try JSONEncoder().encode(TransferEnvelope(encapsulatedKey: sender.encapsulatedKey, ciphertext: ciphertext))
        } catch { throw TransferError.authenticationFailed }
        guard bytes.count <= Self.maximumFrameBytes else { throw TransferError.frameTooLarge }
        try connection.send(bytes)
    }

    private func read(from connection: any TransferConnection) throws -> TransferMessage {
        let bytes = try connection.receive()
        guard bytes.count <= Self.maximumFrameBytes else { throw TransferError.frameTooLarge }
        do {
            let envelope = try JSONDecoder().decode(TransferEnvelope.self, from: bytes)
            guard envelope.encapsulatedKey.count == 32 else { throw TransferError.authenticationFailed }
            let publicKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: peer.publicKey)
            var recipient = try HPKE.Recipient(privateKey: identity.privateKey, ciphersuite: .Curve25519_SHA256_ChachaPoly,
                info: Self.context, encapsulatedKey: envelope.encapsulatedKey, authenticatedBy: publicKey)
            let plaintext = try recipient.open(envelope.ciphertext)
            return try JSONDecoder().decode(TransferMessage.self, from: plaintext)
        } catch { throw TransferError.authenticationFailed }
    }
}
