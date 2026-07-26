import CryptoKit
import Foundation
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

        try store.delete(name: name)
        try store.delete(name: name)
        #expect(try store.listNames().isEmpty)
    }

    @Test func realKeychainLaunchProfileReadsTwoSelectedAndOmitsUnselected() throws {
        let service = "dev.envlatch.tests.\(UUID().uuidString)"
        let store = KeychainSecretStore(service: service)
        let selectedA = try CredentialName(validating: "ENVLATCH_SELECTED_A_TOKEN")
        let selectedB = try CredentialName(validating: "ENVLATCH_SELECTED_B_TOKEN")
        let unselected = try CredentialName(validating: "ENVLATCH_UNSELECTED_TOKEN")
        let values = [
            selectedA: "selected-a-\(UUID().uuidString)",
            selectedB: "selected-b-\(UUID().uuidString)",
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
            .appendingPathComponent("envlatch-real-profile-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let launchStore = LaunchProfileStore(fileURL: root.appendingPathComponent("launch-profiles.json"))
        try launchStore.upsert(
            LaunchProfile(name: "Integration", credentialNames: [selectedA, selectedB])
        )
        let application = CLIApplication(
            store: store,
            environment: ["PATH": "/usr/bin:/bin"],
            endpointProfileStore: EndpointProfileStore(
                fileURL: root.appendingPathComponent("endpoint-profiles.json")
            ),
            launchProfileStore: launchStore,
            stdout: { _ in },
            stderr: { _ in }
        )

        let plan = try application.prepareRun(
            profile: "Integration",
            program: "true",
            arguments: []
        )

        #expect(digest(plan.environment[selectedA.rawValue]) == digest(values[selectedA]))
        #expect(digest(plan.environment[selectedB.rawValue]) == digest(values[selectedB]))
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
