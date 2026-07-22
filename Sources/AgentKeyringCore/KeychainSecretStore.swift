import Foundation
import Security

public protocol SecretStore {
    func listNames() throws -> [CredentialName]
    func save(name: CredentialName, value: String) throws
    func delete(name: CredentialName) throws
    func load(name: CredentialName) throws -> String
    func loadAll() throws -> [String: String]
}

public enum KeychainStoreError: Error, LocalizedError, Sendable {
    case osStatus(operation: String, status: OSStatus)
    case unexpectedResult(operation: String)
    case invalidStoredName(String)
    case invalidStoredValue(String)

    public var errorDescription: String? {
        switch self {
        case .osStatus(let operation, let status):
            let systemMessage = SecCopyErrorMessageString(status, nil) as String? ?? "Unknown Keychain error"
            return "Keychain \(operation) failed (\(status)): \(systemMessage)"
        case .unexpectedResult(let operation):
            return "Keychain returned an unexpected result while trying to \(operation)."
        case .invalidStoredName(let name):
            return "Keychain contains an unsafe AgentKeyring item named \(name). Remove it in Keychain Access."
        case .invalidStoredValue(let name):
            return "Keychain contains an invalid value for \(name). Replace it in AgentKeyring."
        }
    }
}

enum KeychainQueryFactory {
    static func list(service: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrSynchronizable as String: false,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll,
        ]
    }

    static func item(service: String, name: CredentialName) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: name.rawValue,
            kSecAttrSynchronizable as String: false,
        ]
    }

    static func add(
        service: String,
        name: CredentialName,
        valueData: Data,
        access: SecAccess
    ) -> [String: Any] {
        var query = item(service: service, name: name)
        query[kSecAttrLabel as String] = "AgentKeyring · \(name.rawValue)"
        query[kSecValueData as String] = valueData
        query[kSecAttrAccess as String] = access
        return query
    }
}

enum KeychainAccessFactory {
    static func applicationOnly(descriptor: String) throws -> SecAccess {
        var trustedApplication: SecTrustedApplication?
        let trustedStatus = SecTrustedApplicationCreateFromPath(nil, &trustedApplication)
        guard trustedStatus == errSecSuccess, let trustedApplication else {
            throw KeychainStoreError.osStatus(
                operation: "identify the AgentKeyring executable",
                status: trustedStatus
            )
        }

        var access: SecAccess?
        let accessStatus = SecAccessCreate(
            "AgentKeyring · \(descriptor)" as CFString,
            [trustedApplication] as CFArray,
            &access
        )
        guard accessStatus == errSecSuccess, let access else {
            throw KeychainStoreError.osStatus(
                operation: "create application-only access",
                status: accessStatus
            )
        }
        return access
    }
}

public struct KeychainSecretStore: SecretStore {
    public static let productionService = "dev.agentkeyring.secrets"

    public let service: String

    public init(service: String = Self.productionService) {
        self.service = service
    }

    public func listNames() throws -> [CredentialName] {
        var result: CFTypeRef?
        let status = SecItemCopyMatching(KeychainQueryFactory.list(service: service) as CFDictionary, &result)
        if status == errSecItemNotFound {
            return []
        }
        guard status == errSecSuccess else {
            throw KeychainStoreError.osStatus(operation: "list", status: status)
        }
        guard let records = result as? [[String: Any]] else {
            throw KeychainStoreError.unexpectedResult(operation: "list items")
        }

        return try records.map { record in
            guard let rawName = record[kSecAttrAccount as String] as? String else {
                throw KeychainStoreError.unexpectedResult(operation: "read an item name")
            }
            do {
                return try CredentialName(validating: rawName)
            } catch {
                throw KeychainStoreError.invalidStoredName(rawName)
            }
        }.sorted()
    }

    public func save(name: CredentialName, value: String) throws {
        try CredentialName.validateValue(value)
        let valueData = Data(value.utf8)
        let identity = KeychainQueryFactory.item(service: service, name: name)
        let updateStatus = SecItemUpdate(
            identity as CFDictionary,
            [kSecValueData as String: valueData] as CFDictionary
        )

        if updateStatus == errSecSuccess {
            return
        }
        guard updateStatus == errSecItemNotFound else {
            throw KeychainStoreError.osStatus(operation: "replace \(name.rawValue)", status: updateStatus)
        }

        let access = try KeychainAccessFactory.applicationOnly(descriptor: name.rawValue)
        let addQuery = KeychainQueryFactory.add(
            service: service,
            name: name,
            valueData: valueData,
            access: access
        )
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainStoreError.osStatus(operation: "save \(name.rawValue)", status: addStatus)
        }
    }

    public func delete(name: CredentialName) throws {
        let status = SecItemDelete(KeychainQueryFactory.item(service: service, name: name) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainStoreError.osStatus(operation: "delete \(name.rawValue)", status: status)
        }
    }

    public func loadAll() throws -> [String: String] {
        let names = try listNames()
        return try names.reduce(into: [:]) { values, name in
            values[name.rawValue] = try load(name: name)
        }
    }

    public func load(name: CredentialName) throws -> String {
        var query = KeychainQueryFactory.item(service: service, name: name)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else {
            throw KeychainStoreError.osStatus(operation: "read \(name.rawValue)", status: status)
        }
        guard let data = result as? Data, let value = String(data: data, encoding: .utf8) else {
            throw KeychainStoreError.invalidStoredValue(name.rawValue)
        }
        do {
            try CredentialName.validateValue(value)
        } catch {
            throw KeychainStoreError.invalidStoredValue(name.rawValue)
        }
        return value
    }
}
