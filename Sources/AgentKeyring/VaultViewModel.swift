import AgentKeyringCore
import Foundation

@MainActor
final class VaultViewModel: ObservableObject {
    @Published private(set) var names: [CredentialName] = []
    @Published private(set) var profiles: [EndpointProfile] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var statusMessage: String?

    private let store: any SecretStore
    private let profileStore: EndpointProfileStore

    init(
        store: any SecretStore = KeychainSecretStore(),
        profileStore: EndpointProfileStore = .current()
    ) {
        self.store = store
        self.profileStore = profileStore
        refresh()
    }

    func refresh() {
        isLoading = true
        defer { isLoading = false }
        do {
            names = try store.listNames()
            profiles = try profileStore.list()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @discardableResult
    func save(rawName: String, value: String, profile: EndpointProfile?) -> Bool {
        do {
            let name = try CredentialName(validating: rawName)
            let replacing = names.contains(name)
            if !value.isEmpty {
                try CredentialName.validateValue(value)
                try store.save(name: name, value: value)
            } else if !replacing {
                try CredentialName.validateValue(value)
            }
            if let profile {
                try profileStore.upsert(profile)
            } else {
                try profileStore.delete(credentialName: name)
            }
            names = try store.listNames()
            profiles = try profileStore.list()
            errorMessage = nil
            statusMessage = replacing
                ? "Updated \(name.rawValue)."
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
            try profileStore.delete(credentialName: name)
            names = try store.listNames()
            profiles = try profileStore.list()
            errorMessage = nil
            statusMessage = "Deleted \(name.rawValue) from Keychain."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func profile(for name: CredentialName) -> EndpointProfile? {
        profiles.first { $0.credentialName == name }
    }
}
