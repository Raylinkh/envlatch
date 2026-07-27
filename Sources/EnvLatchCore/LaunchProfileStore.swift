import Foundation

public struct LaunchProfileStore: Sendable {
    public let fileURL: URL
    private let legacyEndpointProfileStore: EndpointProfileStore?

    public init(
        fileURL: URL,
        legacyEndpointProfileStore: EndpointProfileStore? = nil
    ) {
        self.fileURL = fileURL
        self.legacyEndpointProfileStore = legacyEndpointProfileStore
    }

    public static func current() -> LaunchProfileStore {
        let directory = PersistenceNamespace.applicationSupportDirectory
        return LaunchProfileStore(
            fileURL: directory.appendingPathComponent("launch-profiles.json"),
            legacyEndpointProfileStore: .current()
        )
    }

    public func list() throws -> [LaunchProfile] {
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return try read().sorted(by: Self.sort)
        }
        let migrated = try legacyProfiles()
        guard !migrated.isEmpty else {
            return []
        }
        try write(migrated)
        return migrated.sorted(by: Self.sort)
    }

    public func listWithoutMigrating() throws -> [LaunchProfile] {
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return try read().sorted(by: Self.sort)
        }
        return try legacyProfiles().sorted(by: Self.sort)
    }

    public func profile(named name: String) throws -> LaunchProfile {
        guard let profile = try list().first(where: {
            $0.name.caseInsensitiveCompare(name) == .orderedSame
        }) else {
            throw LaunchProfileError.profileNotFound(name)
        }
        return profile
    }

    public func upsert(_ profile: LaunchProfile) throws {
        var profiles = try list().filter {
            $0.name.caseInsensitiveCompare(profile.name) != .orderedSame
        }
        profiles.append(profile)
        try write(profiles)
    }

    public func create(_ profile: LaunchProfile) throws {
        var profiles = try listWithoutMigrating()
        guard !profiles.contains(where: {
            $0.name.caseInsensitiveCompare(profile.name) == .orderedSame
        }) else {
            throw LaunchProfileError.profileAlreadyExists(profile.name)
        }
        profiles.append(profile)
        try write(profiles)
    }

    public func delete(named name: String) throws {
        let profiles = try list().filter {
            $0.name.caseInsensitiveCompare(name) != .orderedSame
        }
        try write(profiles)
    }

    public func profileNames(referencing credential: CredentialName) throws -> [String] {
        try list()
            .filter { $0.credentialNames.contains(credential) }
            .map(\.name)
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private func read() throws -> [LaunchProfile] {
        try JSONDecoder().decode([LaunchProfile].self, from: Data(contentsOf: fileURL))
    }

    private func legacyProfiles() throws -> [LaunchProfile] {
        guard let legacyEndpointProfileStore else {
            return []
        }
        return try legacyEndpointProfileStore.list().map {
            try LaunchProfile(name: $0.providerName, credentialNames: [$0.credentialName])
        }
    }

    private func write(_ profiles: [LaunchProfile]) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(profiles.sorted(by: Self.sort)).write(to: fileURL, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
    }

    private static func sort(_ lhs: LaunchProfile, _ rhs: LaunchProfile) -> Bool {
        lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }
}
