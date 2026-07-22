import Foundation
import Testing
@testable import AgentKeyringCore

@Suite("AK-6 open named-host pairing")
struct PairedHostStoreTests {
    @Test func persistsAnyValidHostNameAndDeduplicatesCaseInsensitively() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("agent-keyring-hosts-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("paired-hosts.json")
        let store = PairedHostStore(
            fileURL: file,
            now: { Date(timeIntervalSince1970: 1_700_000_000) }
        )

        try store.register(name: "  Local Build Host  ")
        try store.register(name: "local build host")
        try store.register(name: "Zed Agent")

        let reloaded = try PairedHostStore(fileURL: file).list()
        #expect(reloaded.map(\.name) == ["Local Build Host", "Zed Agent"])
        #expect(reloaded.allSatisfy { $0.pairedAt == Date(timeIntervalSince1970: 1_700_000_000) })
    }

    @Test(arguments: [
        "",
        "   ",
        "line\nbreak",
        String(repeating: "x", count: 81),
    ])
    func rejectsUnsafeOrUnhelpfulNames(_ name: String) throws {
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("agent-keyring-invalid-\(UUID().uuidString).json")
        let store = PairedHostStore(fileURL: file)
        defer { try? FileManager.default.removeItem(at: file) }

        #expect(throws: PairedHostError.self) {
            try store.register(name: name)
        }
    }
}
