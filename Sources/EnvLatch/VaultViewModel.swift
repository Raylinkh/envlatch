import EnvLatchCore
import Foundation

@MainActor
final class VaultViewModel: ObservableObject {
    @Published private(set) var names: [CredentialName] = []
    @Published private(set) var profiles: [EndpointProfile] = []
    @Published private(set) var launchProfiles: [LaunchProfile] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var statusMessage: String?

    private let store: any SecretStore
    private let profileStore: EndpointProfileStore
    private let launchProfileStore: LaunchProfileStore
    private let mutationCoordinator: CredentialMutationCoordinator

    var showsKeyGroups: Bool {
        names.count > 1 || !launchProfiles.isEmpty
    }

    init(
        store: any SecretStore = KeychainSecretStore(),
        profileStore: EndpointProfileStore = .current(),
        launchProfileStore: LaunchProfileStore = .current()
    ) {
        self.store = store
        self.profileStore = profileStore
        self.launchProfileStore = launchProfileStore
        mutationCoordinator = CredentialMutationCoordinator(
            store: store,
            endpointProfileStore: profileStore,
            launchProfileStore: launchProfileStore
        )
        refresh()
    }

    func refresh() {
        isLoading = true
        defer { isLoading = false }
        do {
            names = try store.listNames()
            profiles = try profileStore.list()
            launchProfiles = try launchProfileStore.list()
            errorMessage = nil
        } catch {
            errorMessage = AppLocalization.message(for: error)
        }
    }

    @discardableResult
    func save(rawName: String, value: String, profile: EndpointProfile?) -> Bool {
        do {
            let name = try CredentialName(validating: rawName)
            let replacing = names.contains(name)
            if !replacing, launchProfiles.contains(where: {
                $0.name.caseInsensitiveCompare(name.rawValue) == .orderedSame
            }) {
                throw LaunchProfileError.ambiguousSelection(name.rawValue)
            }
            try mutationCoordinator.save(
                name: name,
                value: value.isEmpty ? nil : value,
                endpoint: profile,
                existingCredential: replacing
            )
            names = try store.listNames()
            profiles = try profileStore.list()
            launchProfiles = try launchProfileStore.list()
            errorMessage = nil
            statusMessage = replacing
                ? AppLocalization.text(
                    "status.key.updated",
                    "Updated \(name.rawValue)."
                )
                : AppLocalization.text(
                    "status.key.saved",
                    "Saved \(name.rawValue) in Keychain."
                )
            return true
        } catch {
            errorMessage = AppLocalization.message(for: error)
            return false
        }
    }

    func delete(_ name: CredentialName) {
        do {
            try mutationCoordinator.delete(name: name)
            names = try store.listNames()
            profiles = try profileStore.list()
            launchProfiles = try launchProfileStore.list()
            errorMessage = nil
            statusMessage = AppLocalization.text(
                "status.key.deleted",
                "Deleted \(name.rawValue) from Keychain."
            )
        } catch {
            errorMessage = AppLocalization.message(for: error)
        }
    }

    func profile(for name: CredentialName) -> EndpointProfile? {
        profiles.first { $0.credentialName == name }
    }

    @discardableResult
    func saveLaunchProfile(_ profile: LaunchProfile) -> Bool {
        do {
            if names.contains(where: {
                $0.rawValue.caseInsensitiveCompare(profile.name) == .orderedSame
            }) {
                throw LaunchProfileError.ambiguousSelection(profile.name)
            }
            try launchProfileStore.upsert(profile)
            launchProfiles = try launchProfileStore.list()
            errorMessage = nil
            statusMessage = AppLocalization.text(
                "status.group.saved",
                "Saved key group \(profile.name)."
            )
            return true
        } catch {
            errorMessage = AppLocalization.message(for: error)
            return false
        }
    }

    func deleteLaunchProfile(_ profile: LaunchProfile) {
        do {
            try launchProfileStore.delete(named: profile.name)
            launchProfiles = try launchProfileStore.list()
            errorMessage = nil
            statusMessage = AppLocalization.text(
                "status.group.deleted",
                "Deleted key group \(profile.name)."
            )
        } catch {
            errorMessage = AppLocalization.message(for: error)
        }
    }
}
