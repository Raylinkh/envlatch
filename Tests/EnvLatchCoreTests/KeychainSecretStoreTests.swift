import Foundation
import Security
import Testing
@testable import EnvLatchCore

@Suite("AK-1, AK-2, and AK-5 Keychain storage", .serialized)
struct KeychainSecretStoreTests {
    @Test func listQueryRequestsAttributesButNeverSecretData() {
        let query = KeychainQueryFactory.list(service: "dev.envlatch.query-test")

        #expect(query[kSecClass as String] as! CFString == kSecClassGenericPassword)
        #expect(query[kSecAttrService as String] as? String == "dev.envlatch.query-test")
        #expect(query[kSecAttrSynchronizable as String] as? Bool == false)
        #expect(query[kSecReturnAttributes as String] as? Bool == true)
        #expect(query[kSecReturnData as String] == nil)
        #expect(query[kSecMatchLimit as String] as! CFString == kSecMatchLimitAll)
    }

    @Test func itemQueryPinsExactAccountAndNonSyncScope() throws {
        let name = try CredentialName(validating: "ENVLATCH_TEST_TOKEN")
        let query = KeychainQueryFactory.item(service: "dev.envlatch.query-test", name: name)

        #expect(query[kSecClass as String] as! CFString == kSecClassGenericPassword)
        #expect(query[kSecAttrService as String] as? String == "dev.envlatch.query-test")
        #expect(query[kSecAttrAccount as String] as? String == name.rawValue)
        #expect(query[kSecAttrSynchronizable as String] as? Bool == false)
    }

    @Test func addQueryCarriesAnExplicitApplicationOnlyACL() throws {
        let name = try CredentialName(validating: "ENVLATCH_TEST_TOKEN")
        let access = try KeychainAccessFactory.applicationOnly(descriptor: name.rawValue)
        let query = KeychainQueryFactory.add(
            service: "dev.envlatch.query-test",
            name: name,
            valueData: Data("disposable".utf8),
            access: access
        )

        #expect(query[kSecAttrAccess as String] != nil)
        #expect(query[kSecValueData as String] as? Data == Data("disposable".utf8))
    }

    @Test func realKeychainRoundTripReplaceAndIdempotentDelete() throws {
        let service = "dev.envlatch.tests.\(UUID().uuidString)"
        let store = KeychainSecretStore(service: service)
        let name = try CredentialName(validating: "ENVLATCH_TEST_TOKEN")
        defer { try? store.delete(name: name) }

        #expect(try store.listNames().isEmpty)

        try store.save(name: name, value: "first-disposable-canary")
        #expect(try store.listNames() == [name])
        #expect(try store.loadAll() == [name.rawValue: "first-disposable-canary"])

        try store.save(name: name, value: "replacement-disposable-canary")
        #expect(try store.loadAll() == [name.rawValue: "replacement-disposable-canary"])

        try store.delete(name: name)
        try store.delete(name: name)
        #expect(try store.listNames().isEmpty)
    }
}
