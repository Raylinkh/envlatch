import CryptoKit
import Foundation
import LocalAuthentication
import Security
import Testing
@testable import EnvLatchCore

@Suite("AK-1, AK-2, and AK-5 Keychain storage", .serialized)
struct KeychainSecretStoreTests {
    @Test func listQueryRequestsAttributesButNeverSecretData() {
        let keychain = try! defaultKeychain()
        let query = KeychainQueryFactory.list(
            service: "dev.envlatch.query-test",
            keychain: keychain
        )

        #expect(query[kSecClass as String] as! CFString == kSecClassGenericPassword)
        #expect(query[kSecAttrService as String] as? String == "dev.envlatch.query-test")
        #expect(query[kSecAttrSynchronizable as String] as? Bool == false)
        #expect(matchesOnly(query, keychain: keychain))
        #expect(query[kSecReturnAttributes as String] as? Bool == true)
        #expect(query[kSecReturnData as String] == nil)
        #expect(query[kSecMatchLimit as String] as! CFString == kSecMatchLimitAll)
    }

    @Test func itemQueryPinsExactAccountAndNonSyncScope() throws {
        let name = try CredentialName(validating: "ENVLATCH_TEST_TOKEN")
        let keychain = try defaultKeychain()
        let query = KeychainQueryFactory.item(
            service: "dev.envlatch.query-test",
            name: name,
            keychain: keychain
        )

        #expect(query[kSecClass as String] as! CFString == kSecClassGenericPassword)
        #expect(query[kSecAttrService as String] as? String == "dev.envlatch.query-test")
        #expect(query[kSecAttrAccount as String] as? String == name.rawValue)
        #expect(query[kSecAttrSynchronizable as String] as? Bool == false)
        #expect(matchesOnly(query, keychain: keychain))
    }

    @Test func addQueryCarriesAnExplicitTrustedApplicationACL() throws {
        let name = try CredentialName(validating: "ENVLATCH_TEST_TOKEN")
        let keychain = try defaultKeychain()
        let access = try KeychainAccessFactory.trustedApplication(descriptor: name.rawValue)
        let query = KeychainQueryFactory.add(
            service: "dev.envlatch.query-test",
            name: name,
            valueData: Data("disposable".utf8),
            access: access,
            keychain: keychain
        )

        #expect(query[kSecAttrAccess as String] != nil)
        #expect(query[kSecValueData as String] as? Data == Data("disposable".utf8))
        #expect(CFEqual(query[kSecUseKeychain as String] as CFTypeRef, keychain))

        let decryptACLs = SecAccessCopyMatchingACLList(
            access,
            kSecACLAuthorizationDecrypt
        ) as? [SecACL] ?? []
        #expect(!decryptACLs.isEmpty)
        var trustedApplicationData: Set<Data> = []
        for acl in decryptACLs {
            var applications: CFArray?
            var description: CFString?
            var promptSelector = SecKeychainPromptSelector()
            #expect(
                SecACLCopyContents(
                    acl,
                    &applications,
                    &description,
                    &promptSelector
                ) == errSecSuccess
            )
            let trustedApplications = applications as? [SecTrustedApplication] ?? []
            #expect(trustedApplications.count == 1)
            for trustedApplication in trustedApplications {
                var applicationData: CFData?
                #expect(
                    SecTrustedApplicationCopyData(
                        trustedApplication,
                        &applicationData
                    ) == errSecSuccess
                )
                if let applicationData {
                    trustedApplicationData.insert(applicationData as Data)
                }
            }
        }
        #expect(trustedApplicationData.count == 1)
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
        var promptFreeQuery = KeychainQueryFactory.item(
            service: service,
            name: name,
            keychain: try defaultKeychain()
        )
        promptFreeQuery[kSecReturnData as String] = true
        let promptFreeContext = LAContext()
        promptFreeContext.interactionNotAllowed = true
        promptFreeQuery[kSecUseAuthenticationContext as String] = promptFreeContext
        for _ in 0..<2 {
            var result: CFTypeRef?
            #expect(SecItemCopyMatching(promptFreeQuery as CFDictionary, &result) == errSecSuccess)
            #expect(result as? Data == Data("replacement-disposable-canary".utf8))
        }

        try store.delete(name: name)
        try store.delete(name: name)
        #expect(try store.listNames().isEmpty)
    }

    @Test func realKeychainDirectSavedKeyAppliesEndpointAndOmitsUnselected() throws {
        let service = "dev.envlatch.tests.\(UUID().uuidString)"
        let store = KeychainSecretStore(service: service)
        let selected = try CredentialName(validating: "ENVLATCH_SELECTED_TOKEN")
        let unselected = try CredentialName(validating: "ENVLATCH_UNSELECTED_TOKEN")
        let values = [
            selected: "selected-\(UUID().uuidString)",
            unselected: "unselected-\(UUID().uuidString)",
        ]
        defer {
            for name in values.keys {
                try? store.delete(name: name)
            }
        }

        for (name, value) in values {
            try store.save(name: name, value: value)
        }

        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("envlatch-real-direct-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let endpointStore = EndpointProfileStore(
            fileURL: root.appendingPathComponent("endpoint-profiles.json")
        )
        try endpointStore.upsert(
            EndpointProfile(
                providerName: "Direct test",
                credentialName: selected,
                contract: .anthropic,
                baseURL: "https://direct.example.com",
                credentialEnvironmentName: CredentialName(validating: "ANTHROPIC_AUTH_TOKEN")
            )
        )
        let application = CLIApplication(
            store: store,
            environment: ["PATH": "/usr/bin:/bin"],
            endpointProfileStore: endpointStore,
            launchProfileStore: LaunchProfileStore(
                fileURL: root.appendingPathComponent("launch-profiles.json")
            ),
            stdout: { _ in },
            stderr: { _ in }
        )

        let plan = try application.prepareRun(
            profile: selected.rawValue,
            program: "true",
            arguments: []
        )

        #expect(digest(plan.environment[selected.rawValue]) == digest(values[selected]))
        #expect(digest(plan.environment["ANTHROPIC_AUTH_TOKEN"]) == digest(values[selected]))
        #expect(plan.environment["ANTHROPIC_BASE_URL"] == "https://direct.example.com")
        #expect(plan.environment[unselected.rawValue] == nil)
    }

    private func digest(_ value: String?) -> String {
        SHA256.hash(data: Data((value ?? "").utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private func defaultKeychain() throws -> SecKeychain {
        var keychain: SecKeychain?
        let status = SecKeychainCopyDefault(&keychain)
        guard status == errSecSuccess, let keychain else {
            throw KeychainStoreError.osStatus(operation: "open the default Keychain", status: status)
        }
        return keychain
    }

    private func matchesOnly(_ query: [String: Any], keychain: SecKeychain) -> Bool {
        guard let searchList = query[kSecMatchSearchList as String] as? [SecKeychain],
              searchList.count == 1 else {
            return false
        }
        return CFEqual(searchList[0], keychain)
    }
}
