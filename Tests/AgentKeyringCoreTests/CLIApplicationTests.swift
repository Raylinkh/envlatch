import Foundation
import Testing
@testable import AgentKeyringCore

@Suite("AK-3 and AK-6 CLI behavior", .serialized)
struct CLIApplicationTests {
    @Test func listAndDoctorNeverReadSecretValues() throws {
        let store = RecordingSecretStore(
            names: [try CredentialName(validating: "OPENAI_API_KEY")],
            values: ["OPENAI_API_KEY": "must-not-be-read"]
        )
        var output: [String] = []
        let application = CLIApplication(
            store: store,
            environment: ["PATH": "/usr/bin:/bin"],
            inspector: InstallationInspector(
                executableURL: URL(fileURLWithPath: "/Applications/AgentKeyring.app/Contents/MacOS/AgentKeyring"),
                linkURL: URL(fileURLWithPath: "/definitely/missing/agent-keyring")
            ),
            identityProvider: { "identifier test" },
            stdout: { output.append($0) },
            stderr: { _ in }
        )

        #expect(application.run(arguments: ["list"]) == 0)
        #expect(application.run(arguments: ["doctor"]) == 0)
        #expect(store.loadAllCallCount == 0)
        #expect(output.contains("OPENAI_API_KEY"))
        #expect(output.allSatisfy { !$0.contains("must-not-be-read") })
    }

    @Test func resolvesExecutableBeforeReadingCredentials() throws {
        let store = RecordingSecretStore(
            names: [try CredentialName(validating: "OPENAI_API_KEY")],
            values: ["OPENAI_API_KEY": "keychain-value"]
        )
        let application = makeApplication(store: store, environment: ["PATH": "/usr/bin:/bin"])

        #expect(throws: PathResolutionError.self) {
            try application.prepareRun(program: "definitely-missing", arguments: [])
        }
        #expect(store.loadAllCallCount == 0)
    }

    @Test func preparesExactDirectExecutionPlan() throws {
        let store = RecordingSecretStore(
            names: [try CredentialName(validating: "GITHUB_TOKEN")],
            values: ["GITHUB_TOKEN": "keychain-value"]
        )
        let application = makeApplication(
            store: store,
            environment: ["PATH": "/usr/bin:/bin", "GITHUB_TOKEN": "wrong"]
        )

        let plan = try application.prepareRun(program: "true", arguments: ["literal value"])
        #expect(plan.executable == "/usr/bin/true")
        #expect(plan.arguments == ["true", "literal value"])
        #expect(plan.environment["GITHUB_TOKEN"] == "keychain-value")
        #expect(store.loadAllCallCount == 1)
    }

    @Test func profileRunLoadsOneKeyAndDerivesContractEnvironment() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("agent-keyring-profile-run-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let profileStore = EndpointProfileStore(fileURL: root.appendingPathComponent("profiles.json"))
        try profileStore.upsert(
            EndpointProfile(
                providerName: "MiniMax Anthropic",
                credentialName: try CredentialName(validating: "MINIMAX_API_KEY"),
                contract: .anthropic,
                baseURL: "https://api.minimaxi.com/anthropic"
            )
        )
        let store = RecordingSecretStore(
            names: [
                try CredentialName(validating: "MINIMAX_API_KEY"),
                try CredentialName(validating: "OPENAI_API_KEY"),
            ],
            values: [
                "MINIMAX_API_KEY": "minimax-secret",
                "OPENAI_API_KEY": "other-secret",
            ]
        )
        let application = makeApplication(
            store: store,
            environment: ["PATH": "/usr/bin:/bin"],
            endpointProfileStore: profileStore
        )

        let plan = try application.prepareRun(
            profile: "MiniMax Anthropic",
            program: "true",
            arguments: []
        )

        #expect(plan.environment["MINIMAX_API_KEY"] == "minimax-secret")
        #expect(plan.environment["ANTHROPIC_AUTH_TOKEN"] == "minimax-secret")
        #expect(plan.environment["ANTHROPIC_BASE_URL"] == "https://api.minimaxi.com/anthropic")
        #expect(plan.environment["OPENAI_API_KEY"] == nil)
        #expect(store.loadedNames == [try CredentialName(validating: "MINIMAX_API_KEY")])
        #expect(store.loadAllCallCount == 0)
    }

    @Test func pairsAnyNamedHostWithoutReadingCredentials() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("agent-keyring-pair-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let registry = PairedHostStore(fileURL: root.appendingPathComponent("paired-hosts.json"))
        let installer = RecordingPairInstaller()
        let store = RecordingSecretStore(
            names: [try CredentialName(validating: "MINIMAX_API_KEY")],
            values: ["MINIMAX_API_KEY": "must-not-be-read"]
        )
        var output: [String] = []
        let application = CLIApplication(
            store: store,
            environment: ["PATH": "/usr/bin:/bin"],
            inspector: InstallationInspector(
                executableURL: URL(fileURLWithPath: "/Applications/AgentKeyring.app/Contents/MacOS/AgentKeyring"),
                linkURL: URL(fileURLWithPath: "/tmp/missing-agent-keyring"),
                pairScriptURL: URL(fileURLWithPath: "/Applications/AgentKeyring.app/Contents/Resources/pair-agents.sh")
            ),
            pairedHostStore: registry,
            pairInstaller: installer,
            identityProvider: { "identifier test" },
            stdout: { output.append($0) },
            stderr: { _ in }
        )

        #expect(application.run(arguments: ["pair", "Local", "Research", "Agent"]) == 0)
        #expect(try registry.list().map(\.name) == ["Local Research Agent"])
        #expect(installer.installCallCount == 1)
        #expect(store.loadAllCallCount == 0)
        #expect(output.contains("paired_host=Local Research Agent"))
        #expect(output.allSatisfy { !$0.contains("must-not-be-read") })
    }

    private func makeApplication(
        store: RecordingSecretStore,
        environment: [String: String],
        endpointProfileStore: EndpointProfileStore? = nil
    ) -> CLIApplication {
        CLIApplication(
            store: store,
            environment: environment,
            inspector: InstallationInspector(
                executableURL: URL(fileURLWithPath: "/Applications/AgentKeyring.app/Contents/MacOS/AgentKeyring"),
                linkURL: URL(fileURLWithPath: "/tmp/missing-agent-keyring")
            ),
            endpointProfileStore: endpointProfileStore ?? EndpointProfileStore(
                fileURL: URL(fileURLWithPath: "/tmp/agent-keyring-missing-profiles-\(UUID().uuidString).json")
            ),
            identityProvider: { "identifier test" },
            stdout: { _ in },
            stderr: { _ in }
        )
    }
}

private final class RecordingPairInstaller: PairInstalling {
    var installCallCount = 0

    func install(scriptURL: URL, environment: [String: String]) throws {
        installCallCount += 1
    }
}

private final class RecordingSecretStore: SecretStore {
    let names: [CredentialName]
    let values: [String: String]
    var loadAllCallCount = 0
    var loadedNames: [CredentialName] = []

    init(names: [CredentialName], values: [String: String]) {
        self.names = names
        self.values = values
    }

    func listNames() throws -> [CredentialName] { names }
    func save(name: CredentialName, value: String) throws {}
    func delete(name: CredentialName) throws {}
    func load(name: CredentialName) throws -> String {
        loadedNames.append(name)
        return values[name.rawValue] ?? ""
    }
    func loadAll() throws -> [String: String] {
        loadAllCallCount += 1
        return values
    }
}
