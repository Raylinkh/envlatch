import Foundation
import Testing
@testable import EnvLatchCore

@Suite("AK-2 endpoint profiles")
struct EndpointProfileStoreTests {
    @Test func persistsOnlyNonSecretConnectionMetadata() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("envlatch-profiles-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("profiles.json")
        let store = EndpointProfileStore(fileURL: file)
        let profile = try EndpointProfile(
            providerName: "MiniMax China",
            credentialName: CredentialName(validating: "MINIMAX_API_KEY"),
            contract: .anthropic,
            baseURL: "https://api.minimaxi.com/anthropic"
        )

        try store.upsert(profile)

        #expect(try store.list() == [profile])
        let persisted = try String(contentsOf: file, encoding: .utf8)
        #expect(persisted.contains("MiniMax China"))
        #expect(persisted.contains("anthropic"))
        #expect(persisted.contains("api.minimaxi.com"))
        #expect(!persisted.contains("secret"))
    }

    @Test func exposesContractBindingsWithoutEmbeddingASecret() throws {
        let profile = try EndpointProfile(
            providerName: "MiniMax China",
            credentialName: CredentialName(validating: "MINIMAX_API_KEY"),
            contract: .anthropic,
            baseURL: "https://api.minimaxi.com/anthropic"
        )

        #expect(profile.secretEnvironmentNames == [
            "MINIMAX_API_KEY",
            "ANTHROPIC_AUTH_TOKEN",
        ])
        #expect(profile.configurationEnvironment == [
            "ANTHROPIC_BASE_URL": "https://api.minimaxi.com/anthropic",
        ])
    }

    @Test(arguments: [
        ("", "https://api.example.com"),
        ("Provider", "file:///tmp/key"),
        ("Provider", "http://api.example.com"),
        ("Provider", "https://user:password@example.com"),
        ("Provider", "https://api.example.com/v1?api_key=secret"),
        ("Provider", "https://api.example.com/v1#secret"),
    ])
    func rejectsInvalidProfiles(provider: String, baseURL: String) throws {
        #expect(throws: EndpointProfileError.self) {
            try EndpointProfile(
                providerName: provider,
                credentialName: CredentialName(validating: "EXAMPLE_API_KEY"),
                contract: .openAIChat,
                baseURL: baseURL
            )
        }
    }

    @Test func permitsPlainHTTPOnlyForExplicitLoopbackHosts() throws {
        for baseURL in ["http://localhost:8317/v1", "http://127.0.0.1:8317/v1", "http://[::1]:8317/v1"] {
            _ = try EndpointProfile(
                providerName: "Local proxy",
                credentialName: CredentialName(validating: "LOCAL_API_KEY"),
                contract: .openAIResponses,
                baseURL: baseURL
            )
        }
    }

    @Test func duplicateProviderLabelsPreserveEachCredentialEndpoint() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("envlatch-profile-lookup-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = EndpointProfileStore(fileURL: root.appendingPathComponent("profiles.json"))
        let first = try EndpointProfile(
            providerName: "Compatible gateway",
            credentialName: CredentialName(validating: "FIRST_API_KEY"),
            contract: .openAIResponses,
            baseURL: "https://first.example.com/v1"
        )
        let second = try EndpointProfile(
            providerName: "Compatible gateway",
            credentialName: CredentialName(validating: "SECOND_API_KEY"),
            contract: .openAIChat,
            baseURL: "https://second.example.com/v1"
        )
        try store.upsert(first)
        try store.upsert(second)

        #expect(try store.list().count == 2)
        #expect(try store.endpoint(for: first.credentialName) == first)
        #expect(try store.endpoint(for: second.credentialName) == second)
    }
}
