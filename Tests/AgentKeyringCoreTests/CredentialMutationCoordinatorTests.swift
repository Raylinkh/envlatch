import Foundation
import Testing
@testable import AgentKeyringCore

@Suite("AK-1, AK-2, and AK-4 failure-safe mutations")
struct CredentialMutationCoordinatorTests {
    @Test func restoresPriorEndpointWhenKeychainSaveFails() throws {
        let fixture = try MutationFixture()
        defer { fixture.cleanup() }
        let name = try CredentialName(validating: "OPENAI_API_KEY")
        let previous = try EndpointProfile(
            providerName: "OpenAI",
            credentialName: name,
            contract: .openAIResponses,
            baseURL: "https://api.openai.com/v1"
        )
        try fixture.endpointStore.upsert(previous)
        fixture.secretStore.saveError = MutationTestError.forced
        let replacement = try EndpointProfile(
            providerName: "Proxy",
            credentialName: name,
            contract: .openAIResponses,
            baseURL: "https://proxy.example.com/v1"
        )

        #expect(throws: MutationTestError.self) {
            try fixture.coordinator.save(
                name: name,
                value: "replacement-secret",
                endpoint: replacement,
                existingCredential: true
            )
        }

        #expect(try fixture.endpointStore.list() == [previous])
    }

    @Test func endpointWriteFailureDoesNotTouchKeychain() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("agent-keyring-mutation-blocked-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let blocker = root.appendingPathComponent("not-a-directory")
        try Data("block".utf8).write(to: blocker)
        let endpointStore = EndpointProfileStore(fileURL: blocker.appendingPathComponent("profiles.json"))
        let launchStore = LaunchProfileStore(fileURL: root.appendingPathComponent("launch.json"))
        let secretStore = MutationSecretStore()
        let coordinator = CredentialMutationCoordinator(
            store: secretStore,
            endpointProfileStore: endpointStore,
            launchProfileStore: launchStore
        )
        let name = try CredentialName(validating: "OPENAI_API_KEY")
        let endpoint = try EndpointProfile(
            providerName: "OpenAI",
            credentialName: name,
            contract: .openAIResponses,
            baseURL: "https://api.openai.com/v1"
        )

        #expect(throws: (any Error).self) {
            try coordinator.save(
                name: name,
                value: "new-secret",
                endpoint: endpoint,
                existingCredential: false
            )
        }
        #expect(secretStore.saveCallCount == 0)
    }

    @Test func referencedCredentialCannotBeDeleted() throws {
        let fixture = try MutationFixture()
        defer { fixture.cleanup() }
        let name = try CredentialName(validating: "OPENAI_API_KEY")
        try fixture.launchStore.upsert(LaunchProfile(name: "Backend", credentialNames: [name]))

        #expect(throws: LaunchProfileError.self) {
            try fixture.coordinator.delete(name: name)
        }
        #expect(fixture.secretStore.deleteCallCount == 0)
    }
}

private enum MutationTestError: Error {
    case forced
}

private final class MutationSecretStore: SecretStore {
    var saveError: (any Error)?
    var deleteError: (any Error)?
    var saveCallCount = 0
    var deleteCallCount = 0

    func listNames() throws -> [CredentialName] { [] }
    func save(name: CredentialName, value: String) throws {
        saveCallCount += 1
        if let saveError { throw saveError }
    }
    func delete(name: CredentialName) throws {
        deleteCallCount += 1
        if let deleteError { throw deleteError }
    }
    func load(name: CredentialName) throws -> String { "" }
    func loadAll() throws -> [String: String] { [:] }
}

private struct MutationFixture {
    let root: URL
    let secretStore: MutationSecretStore
    let endpointStore: EndpointProfileStore
    let launchStore: LaunchProfileStore
    let coordinator: CredentialMutationCoordinator

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("agent-keyring-mutation-\(UUID().uuidString)", isDirectory: true)
        secretStore = MutationSecretStore()
        endpointStore = EndpointProfileStore(fileURL: root.appendingPathComponent("endpoint.json"))
        launchStore = LaunchProfileStore(fileURL: root.appendingPathComponent("launch.json"))
        coordinator = CredentialMutationCoordinator(
            store: secretStore,
            endpointProfileStore: endpointStore,
            launchProfileStore: launchStore
        )
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: root)
    }
}
