import Foundation
import Testing
@testable import AgentKeyringCore

@Suite("AK-2 and AK-3 least-privilege launch profiles")
struct LaunchProfileStoreTests {
    @Test func persistsExactUniqueCredentialMembership() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("agent-keyring-launch-profiles-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = LaunchProfileStore(fileURL: root.appendingPathComponent("launch-profiles.json"))
        let profile = try LaunchProfile(
            name: "Backend",
            credentialNames: [
                CredentialName(validating: "OPENAI_API_KEY"),
                CredentialName(validating: "SENTRY_AUTH_TOKEN"),
            ]
        )

        try store.upsert(profile)

        #expect(try store.list() == [profile])
        #expect(try store.profile(named: "backend") == profile)
        #expect(try store.profileNames(referencing: CredentialName(validating: "OPENAI_API_KEY")) == ["Backend"])
        let persisted = try String(contentsOf: store.fileURL, encoding: .utf8)
        #expect(persisted.contains("OPENAI_API_KEY"))
        #expect(!persisted.contains("secret-value"))
    }

    @Test func rejectsEmptyAndDuplicateMembership() throws {
        #expect(throws: LaunchProfileError.self) {
            try LaunchProfile(name: "Empty", credentialNames: [])
        }
        let credential = try CredentialName(validating: "OPENAI_API_KEY")
        #expect(throws: LaunchProfileError.self) {
            try LaunchProfile(name: "Duplicate", credentialNames: [credential, credential])
        }
    }

    @Test func bootstrapsSingleKeyLaunchProfilesFromExistingEndpointMetadata() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("agent-keyring-profile-bootstrap-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let endpointStore = EndpointProfileStore(fileURL: root.appendingPathComponent("endpoint-profiles.json"))
        try endpointStore.upsert(
            EndpointProfile(
                providerName: "MiniMax China",
                credentialName: CredentialName(validating: "MINIMAX_API_KEY"),
                contract: .anthropic,
                baseURL: "https://api.minimaxi.com/anthropic"
            )
        )
        let store = LaunchProfileStore(
            fileURL: root.appendingPathComponent("launch-profiles.json"),
            legacyEndpointProfileStore: endpointStore
        )

        #expect(try store.list() == [
            LaunchProfile(
                name: "MiniMax China",
                credentialNames: [CredentialName(validating: "MINIMAX_API_KEY")]
            ),
        ])
        #expect(FileManager.default.fileExists(atPath: store.fileURL.path))
    }
}
