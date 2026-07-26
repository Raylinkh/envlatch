import Foundation
import Testing
@testable import EnvLatch
@testable import EnvLatchCore

@Suite("AK-4 visible GUI Keychain failures")
@MainActor
struct VaultViewModelTests {
    @Test func deniedKeychainRefreshShowsSafeErrorAndNoCredentialValue() {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("envlatch-viewmodel-denial-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = DeniedSecretStore()

        let model = VaultViewModel(
            store: store,
            profileStore: EndpointProfileStore(fileURL: root.appendingPathComponent("endpoints.json")),
            launchProfileStore: LaunchProfileStore(fileURL: root.appendingPathComponent("launches.json"))
        )

        #expect(model.names.isEmpty)
        #expect(model.errorMessage == DeniedSecretStore.message)
        #expect(!(model.errorMessage ?? "").contains(DeniedSecretStore.canary))
    }

    @Test func keyGroupsStayHiddenUntilTheyAreUseful() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("envlatch-key-group-visibility-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let first = try CredentialName(validating: "FIRST_API_KEY")
        let second = try CredentialName(validating: "SECOND_API_KEY")
        let endpoints = EndpointProfileStore(fileURL: root.appendingPathComponent("endpoints.json"))
        let groups = LaunchProfileStore(fileURL: root.appendingPathComponent("groups.json"))

        let oneKeyModel = VaultViewModel(
            store: StaticSecretStore(names: [first]),
            profileStore: endpoints,
            launchProfileStore: groups
        )
        #expect(oneKeyModel.showsKeyGroups == false)

        let twoKeyModel = VaultViewModel(
            store: StaticSecretStore(names: [first, second]),
            profileStore: endpoints,
            launchProfileStore: groups
        )
        #expect(twoKeyModel.showsKeyGroups)

        try groups.upsert(LaunchProfile(name: "Existing", credentialNames: [first]))
        let existingGroupModel = VaultViewModel(
            store: StaticSecretStore(names: [first]),
            profileStore: endpoints,
            launchProfileStore: groups
        )
        #expect(existingGroupModel.showsKeyGroups)
    }
}

private struct StaticSecretStore: SecretStore {
    let names: [CredentialName]

    func listNames() throws -> [CredentialName] { names }
    func save(name: CredentialName, value: String) throws {}
    func delete(name: CredentialName) throws {}
    func load(name: CredentialName) throws -> String { "" }
    func loadAll() throws -> [String: String] { [:] }
}

private struct DeniedSecretStore: SecretStore {
    static let canary = "must-never-appear"
    static let message = "Keychain access was denied. Unlock or allow access, then retry."

    func listNames() throws -> [CredentialName] {
        throw DeniedSecretStoreError.denied
    }

    func save(name: CredentialName, value: String) throws {
        throw DeniedSecretStoreError.denied
    }

    func delete(name: CredentialName) throws {
        throw DeniedSecretStoreError.denied
    }

    func load(name: CredentialName) throws -> String {
        throw DeniedSecretStoreError.denied
    }

    func loadAll() throws -> [String: String] {
        throw DeniedSecretStoreError.denied
    }
}

private enum DeniedSecretStoreError: Error, LocalizedError {
    case denied

    var errorDescription: String? {
        DeniedSecretStore.message
    }
}
