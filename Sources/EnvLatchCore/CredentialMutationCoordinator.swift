import Foundation

public enum CredentialMutationError: Error, LocalizedError {
    case rollbackFailed(original: String, rollback: String)

    public var errorDescription: String? {
        switch self {
        case .rollbackFailed(let original, let rollback):
            "The operation failed and EnvLatch could not restore the previous endpoint metadata. Original error: \(original). Rollback error: \(rollback)."
        }
    }
}

public struct CredentialMutationCoordinator {
    private let store: any SecretStore
    private let endpointProfileStore: EndpointProfileStore
    private let launchProfileStore: LaunchProfileStore

    public init(
        store: any SecretStore,
        endpointProfileStore: EndpointProfileStore,
        launchProfileStore: LaunchProfileStore
    ) {
        self.store = store
        self.endpointProfileStore = endpointProfileStore
        self.launchProfileStore = launchProfileStore
    }

    public func save(
        name: CredentialName,
        value: String?,
        endpoint: EndpointProfile?,
        existingCredential: Bool
    ) throws {
        if let value {
            try CredentialName.validateValue(value)
        } else if !existingCredential {
            throw CredentialValidationError.emptyValue
        }

        let previousEndpoint = try endpointProfileStore.endpoint(for: name)
        if let endpoint {
            try endpointProfileStore.upsert(endpoint)
        } else {
            try endpointProfileStore.delete(credentialName: name)
        }

        guard let value else {
            return
        }

        do {
            try store.save(name: name, value: value)
        } catch {
            let original = error
            do {
                try restore(previousEndpoint, for: name)
            } catch {
                throw CredentialMutationError.rollbackFailed(
                    original: original.localizedDescription,
                    rollback: error.localizedDescription
                )
            }
            throw original
        }
    }

    public func delete(name: CredentialName) throws {
        let references = try launchProfileStore.profileNames(referencing: name)
        guard references.isEmpty else {
            throw LaunchProfileError.credentialInUse(
                credential: name.rawValue,
                profiles: references
            )
        }

        let previousEndpoint = try endpointProfileStore.endpoint(for: name)
        try endpointProfileStore.delete(credentialName: name)
        do {
            try store.delete(name: name)
        } catch {
            let original = error
            do {
                try restore(previousEndpoint, for: name)
            } catch {
                throw CredentialMutationError.rollbackFailed(
                    original: original.localizedDescription,
                    rollback: error.localizedDescription
                )
            }
            throw original
        }
    }

    private func restore(_ endpoint: EndpointProfile?, for name: CredentialName) throws {
        if let endpoint {
            try endpointProfileStore.upsert(endpoint)
        } else {
            try endpointProfileStore.delete(credentialName: name)
        }
    }
}
