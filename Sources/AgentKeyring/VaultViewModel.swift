import AgentKeyringCore
import Foundation

@MainActor
final class VaultViewModel: ObservableObject {
    @Published private(set) var names: [CredentialName] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var statusMessage: String?

    private let store: any SecretStore

    init(store: any SecretStore = KeychainSecretStore()) {
        self.store = store
        refresh()
    }

    func refresh() {
        isLoading = true
        defer { isLoading = false }
        do {
            names = try store.listNames()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @discardableResult
    func save(rawName: String, value: String) -> Bool {
        do {
            let name = try CredentialName(validating: rawName)
            try CredentialName.validateValue(value)
            let replacing = names.contains(name)
            try store.save(name: name, value: value)
            names = try store.listNames()
            errorMessage = nil
            statusMessage = replacing
                ? "Replaced \(name.rawValue) in Keychain."
                : "Saved \(name.rawValue) in Keychain."
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func delete(_ name: CredentialName) {
        do {
            try store.delete(name: name)
            names = try store.listNames()
            errorMessage = nil
            statusMessage = "Deleted \(name.rawValue) from Keychain."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
