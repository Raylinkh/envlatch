import Foundation

public enum LaunchProfileError: Error, Equatable, LocalizedError, Sendable {
    case invalidName
    case emptyCredentials
    case duplicateCredential(String)
    case profileNotFound(String)
    case ambiguousSelection(String)
    case missingCredential(profile: String, credential: String)
    case conflictingSecretEnvironment(name: String, first: String, second: String)
    case conflictingConfigurationEnvironment(name: String)
    case credentialInUse(credential: String, profiles: [String])

    public var errorDescription: String? {
        switch self {
        case .invalidName:
            "Use a key-group name between 1 and 80 characters with no control characters."
        case .emptyCredentials:
            "Select at least one saved key for the key group."
        case .duplicateCredential(let name):
            "The key group contains \(name) more than once."
        case .profileNotFound(let name):
            "No saved key or key group is named \(name). Run `envlatch list` or `envlatch groups` to see available names."
        case .ambiguousSelection(let name):
            "A saved key and key group are both named \(name). Rename or delete the key group before launching."
        case .missingCredential(let profile, let credential):
            "Key group \(profile) references missing key \(credential). Edit the group before launching."
        case .conflictingSecretEnvironment(let name, let first, let second):
            "Key group maps both \(first) and \(second) to \(name). Give each selected key a distinct target environment name."
        case .conflictingConfigurationEnvironment(let name):
            "Key group contains conflicting values for \(name). Split those endpoints into separate groups."
        case .credentialInUse(let credential, let profiles):
            "Remove \(credential) from key group(s) \(profiles.joined(separator: ", ")) before deleting it."
        }
    }
}

public struct LaunchProfile: Codable, Equatable, Identifiable, Sendable {
    public let name: String
    public let credentialNames: [CredentialName]

    public var id: String { name.lowercased() }

    public init(name rawName: String, credentialNames: [CredentialName]) throws {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty,
              name.count <= 80,
              name.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }) else {
            throw LaunchProfileError.invalidName
        }
        guard !credentialNames.isEmpty else {
            throw LaunchProfileError.emptyCredentials
        }
        var seen: Set<CredentialName> = []
        for credential in credentialNames where !seen.insert(credential).inserted {
            throw LaunchProfileError.duplicateCredential(credential.rawValue)
        }
        self.name = name
        self.credentialNames = credentialNames
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case credentialNames
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            name: container.decode(String.self, forKey: .name),
            credentialNames: try container.decode([String].self, forKey: .credentialNames)
                .map(CredentialName.init(validating:))
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(credentialNames.map(\.rawValue), forKey: .credentialNames)
    }
}
