import CryptoKit
import Foundation
import Security

public struct KeychainTransferIdentityStore {
    public static let productionService = "dev.agentkeyring.transfer-identity.v1"
    public let service: String

    public init(service: String = Self.productionService) { self.service = service }

    public func loadOrCreate() throws -> TransferIdentity {
        let keychain = try KeychainTarget.defaultKeychain()
        let name = try CredentialName(validating: "ENVLATCH_TRANSFER_PRIVATE_KEY")
        var query = KeychainQueryFactory.item(service: service, name: name, keychain: keychain)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess {
            guard let data = result as? Data else { throw TransferError.metadata }
            do { return TransferIdentity(privateKey: try .init(rawRepresentation: data)) }
            catch { throw TransferError.metadata }
        }
        guard status == errSecItemNotFound else {
            throw KeychainStoreError.osStatus(operation: "read transfer identity", status: status)
        }
        let identity = TransferIdentity()
        let access = try KeychainAccessFactory.trustedApplication(descriptor: "transfer identity")
        let add = KeychainQueryFactory.add(service: service, name: name,
            valueData: identity.privateKey.rawRepresentation, access: access, keychain: keychain)
        let addStatus = SecItemAdd(add as CFDictionary, nil)
        if addStatus == errSecDuplicateItem {
            // Another process won creation; use that identity rather than rotate it.
            let readStatus = SecItemCopyMatching(query as CFDictionary, &result)
            guard readStatus == errSecSuccess, let data = result as? Data else { throw TransferError.metadata }
            do { return TransferIdentity(privateKey: try .init(rawRepresentation: data)) }
            catch { throw TransferError.metadata }
        }
        guard addStatus == errSecSuccess else {
            throw KeychainStoreError.osStatus(operation: "create transfer identity", status: addStatus)
        }
        return identity
    }
}
