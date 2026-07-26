import Foundation

public struct PairedHost: Codable, Equatable, Identifiable, Sendable {
    public let name: String
    public let pairedAt: Date

    public var id: String { name.lowercased() }
}

public enum PairedHostError: Error, Equatable, LocalizedError, Sendable {
    case invalidName

    public var errorDescription: String? {
        switch self {
        case .invalidName:
            "Use a name between 1 and 80 characters with no line breaks or control characters."
        }
    }
}

public struct PairedHostStore: Sendable {
    public let fileURL: URL
    private let now: @Sendable () -> Date

    public init(
        fileURL: URL,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.fileURL = fileURL
        self.now = now
    }

    public static func current() -> PairedHostStore {
        let fileURL = PersistenceNamespace.applicationSupportDirectory
            .appendingPathComponent("paired-hosts.json")
        return PairedHostStore(fileURL: fileURL)
    }

    public func list() throws -> [PairedHost] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([PairedHost].self, from: data)
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    @discardableResult
    public func register(name rawName: String) throws -> PairedHost {
        let name = try validatedName(rawName)
        var hosts = try list()
        if let existing = hosts.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            return existing
        }

        let host = PairedHost(name: name, pairedAt: now())
        hosts.append(host)
        hosts.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        try write(hosts)
        return host
    }

    private func validatedName(_ rawName: String) throws -> String {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty,
              name.count <= 80,
              name.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }) else {
            throw PairedHostError.invalidName
        }
        return name
    }

    private func write(_ hosts: [PairedHost]) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(hosts).write(to: fileURL, options: .atomic)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: fileURL.path
        )
    }
}
