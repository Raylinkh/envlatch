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
