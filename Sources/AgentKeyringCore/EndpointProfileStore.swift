import Foundation

public struct EndpointProfileStore: Sendable {
    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public static func current() -> EndpointProfileStore {
        let fileURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/AgentKeyring", isDirectory: true)
            .appendingPathComponent("endpoint-profiles.json")
        return EndpointProfileStore(fileURL: fileURL)
    }

    public func list() throws -> [EndpointProfile] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        return try JSONDecoder().decode([EndpointProfile].self, from: Data(contentsOf: fileURL))
            .sorted { $0.providerName.localizedCaseInsensitiveCompare($1.providerName) == .orderedAscending }
    }

    public func profile(matching identifier: String) throws -> EndpointProfile {
        let match = try list().first {
            $0.providerName.caseInsensitiveCompare(identifier) == .orderedSame
                || $0.credentialName.rawValue.caseInsensitiveCompare(identifier) == .orderedSame
        }
        guard let match else {
            throw EndpointProfileError.profileNotFound(identifier)
        }
        return match
    }

    public func upsert(_ profile: EndpointProfile) throws {
        var profiles = try list().filter {
            $0.credentialName != profile.credentialName
                && $0.providerName.caseInsensitiveCompare(profile.providerName) != .orderedSame
        }
        profiles.append(profile)
        try write(profiles)
    }

    public func delete(credentialName: CredentialName) throws {
        let profiles = try list().filter { $0.credentialName != credentialName }
        try write(profiles)
    }

    private func write(_ profiles: [EndpointProfile]) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let sorted = profiles.sorted {
            $0.providerName.localizedCaseInsensitiveCompare($1.providerName) == .orderedAscending
        }
        try encoder.encode(sorted).write(to: fileURL, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
    }
}
