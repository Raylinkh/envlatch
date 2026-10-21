import CryptoKit
import Foundation

public enum TransferError: Error, Equatable, LocalizedError, Sendable {
    case invalidInput, untrustedPeer, trustAlreadyExists, consentRequired, denied
    case authenticationFailed, protocolViolation, frameTooLarge, transport, timeout
    case metadata, bindingMismatch, outcomeUnknown, collision, groupConflict

    public var errorDescription: String? {
        switch self {
        case .invalidInput: "Invalid transfer name, identity, operation, or numeric tailnet address."
        case .untrustedPeer: "This transfer peer has not been approved locally."
        case .trustAlreadyExists: "Peer trust already exists; replacing trust is not supported."
        case .consentRequired: "Transfer approval requires a controlling terminal."
        case .denied: "Transfer approval was cancelled."
        case .authenticationFailed: "The transfer message could not be authenticated."
        case .protocolViolation: "The transfer message is invalid for this exchange."
        case .frameTooLarge: "The transfer message exceeds the size limit."
        case .transport: "The transfer connection closed or failed. Check operation status."
        case .timeout: "The transfer connection timed out. Check operation status."
        case .metadata: "Transfer metadata could not be safely read or persisted."
        case .bindingMismatch: "The transfer operation does not match the approved key and peers."
        case .outcomeUnknown: "The operation outcome is unknown. Do not retry delivery with this operation."
        case .collision: "The target already has this key. No value was replaced."
        case .groupConflict: "The saved name conflicts with a target key group."
        }
    }
}

public protocol TransferSecretStore {
    func contains(name: CredentialName) throws -> Bool
    func load(name: CredentialName) throws -> String
    func create(name: CredentialName, value: String) throws
}

public struct TransferIdentity: Sendable {
    // Private material never participates in Codable, descriptions, or CLI output.
    let privateKey: Curve25519.KeyAgreement.PrivateKey

    public init(privateKey: Curve25519.KeyAgreement.PrivateKey = .init()) {
        self.privateKey = privateKey
    }

    public var publicKey: Data { privateKey.publicKey.rawRepresentation }
    public var fingerprint: String { Self.fingerprint(publicKey) }

    public static func fingerprint(_ publicKey: Data) -> String {
        SHA256.hash(data: publicKey).map { String(format: "%02x", $0) }.joined()
    }
}

public struct TransferPeer: Codable, Equatable, Sendable {
    public let name: String
    public let publicKey: Data
    public let address: String
    public let port: UInt16
    public var fingerprint: String { TransferIdentity.fingerprint(publicKey) }

    public init(name: String, publicKey: Data, address: String, port: UInt16 = 49271) throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, name.count <= 80,
              name.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }),
              publicKey.count == 32, port > 0, Self.isTailnetAddress(address) else {
            throw TransferError.invalidInput
        }
        _ = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: publicKey)
        self.name = name
        self.publicKey = publicKey
        self.address = address
        self.port = port
    }

    public static func isTailnetAddress(_ address: String) -> Bool {
        let parts = address.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return false }
        let bytes = parts.compactMap { UInt8($0) }
        return bytes.count == 4 && bytes[0] == 100 && (64...127).contains(bytes[1])
            && zip(parts, bytes).allSatisfy { String($0.1) == $0.0 }
    }
}

public struct TransferBinding: Codable, Equatable, Sendable {
    public let operationID: UUID
    public let credentialName: String
    public let sourceFingerprint: String
    public let targetFingerprint: String

    public init(operationID: UUID, credentialName: String,
                sourceFingerprint: String, targetFingerprint: String) throws {
        guard credentialName.utf8.count <= 256,
              Self.validFingerprint(sourceFingerprint), Self.validFingerprint(targetFingerprint),
              sourceFingerprint != targetFingerprint else { throw TransferError.invalidInput }
        _ = try CredentialName(validating: credentialName)
        self.operationID = operationID
        self.credentialName = credentialName
        self.sourceFingerprint = sourceFingerprint
        self.targetFingerprint = targetFingerprint
    }

    private static func validFingerprint(_ value: String) -> Bool {
        value.utf8.count == 64 && value.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
    }
}

public enum TransferRecordState: String, Codable, Sendable { case reserved, committed, rejected }
public enum TransferRejection: String, Codable, Sendable { case collision, groupConflict }

public struct TransferRecord: Codable, Equatable, Sendable {
    public let binding: TransferBinding
    public let state: TransferRecordState
    public let rejection: TransferRejection?

    public init(binding: TransferBinding, state: TransferRecordState, rejection: TransferRejection? = nil) {
        self.binding = binding
        self.state = state
        self.rejection = rejection
    }

    public var status: String { state == .reserved ? "unknown" : state.rawValue }
}

public struct TransferConsentRequest: Sendable {
    public enum Direction: String, Sendable { case send, receive }
    public let direction: Direction
    public let binding: TransferBinding
    public let peer: TransferPeer
}

public protocol TransferConnection: AnyObject {
    func send(_ frame: Data) throws
    func receive() throws -> Data
    func close()
}
