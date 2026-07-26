import Foundation

public struct EndpointProfileStore: Sendable {
    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public static func current() -> EndpointProfileStore {
        let fileURL = PersistenceNamespace.applicationSupportDirectory
            .appendingPathComponent("endpoint-profiles.json")
        return EndpointProfileStore(fileURL: fileURL)
    }

    public func list() throws -> [EndpointProfile] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        return try JSONDecoder().decode([EndpointProfile].self, from: Data(contentsOf: fileURL))
            .sorted(by: precedes)
    }

    public func endpoint(for credentialName: CredentialName) throws -> EndpointProfile? {
        try list().first { $0.credentialName == credentialName }
    }

    public func upsert(_ profile: EndpointProfile) throws {
        var profiles = try list().filter { $0.credentialName != profile.credentialName }
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
        let sorted = profiles.sorted(by: precedes)
        try encoder.encode(sorted).write(to: fileURL, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
    }

    private func precedes(_ lhs: EndpointProfile, _ rhs: EndpointProfile) -> Bool {
        let providerOrder = lhs.providerName.localizedCaseInsensitiveCompare(rhs.providerName)
        if providerOrder == .orderedSame {
            return lhs.credentialName.rawValue < rhs.credentialName.rawValue
        }
        return providerOrder == .orderedAscending
    }
}
