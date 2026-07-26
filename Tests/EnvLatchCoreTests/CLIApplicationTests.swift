import Foundation
import Testing
@testable import EnvLatchCore

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
                executableURL: URL(fileURLWithPath: "/Applications/EnvLatch.app/Contents/MacOS/EnvLatch"),
                linkURL: URL(fileURLWithPath: "/definitely/missing/envlatch")
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

    @Test func profileRunLoadsOnlySelectedKeysAndDerivesEachEndpointEnvironment() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("envlatch-profile-run-\(UUID().uuidString)", isDirectory: true)
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
        try profileStore.upsert(
            EndpointProfile(
                providerName: "OpenRouter",
                credentialName: try CredentialName(validating: "OPENROUTER_API_KEY"),
                contract: .openAIResponses,
                baseURL: "https://openrouter.ai/api/v1"
            )
        )
        let launchProfileStore = LaunchProfileStore(fileURL: root.appendingPathComponent("launch-profiles.json"))
        try launchProfileStore.upsert(
            LaunchProfile(
                name: "Backend",
                credentialNames: [
                    try CredentialName(validating: "MINIMAX_API_KEY"),
                    try CredentialName(validating: "OPENROUTER_API_KEY"),
                ]
            )
        )
        let store = RecordingSecretStore(
            names: [
                try CredentialName(validating: "MINIMAX_API_KEY"),
                try CredentialName(validating: "OPENROUTER_API_KEY"),
                try CredentialName(validating: "UNSELECTED_API_KEY"),
            ],
            values: [
                "MINIMAX_API_KEY": "minimax-secret",
                "OPENROUTER_API_KEY": "openrouter-secret",
                "UNSELECTED_API_KEY": "unselected-secret",
            ]
        )
        let application = makeApplication(
            store: store,
            environment: ["PATH": "/usr/bin:/bin"],
            endpointProfileStore: profileStore,
            launchProfileStore: launchProfileStore
        )

        let plan = try application.prepareRun(
            profile: "Backend",
            program: "true",
            arguments: []
        )

        #expect(plan.environment["MINIMAX_API_KEY"] == "minimax-secret")
        #expect(plan.environment["ANTHROPIC_AUTH_TOKEN"] == "minimax-secret")
        #expect(plan.environment["ANTHROPIC_BASE_URL"] == "https://api.minimaxi.com/anthropic")
        #expect(plan.environment["OPENROUTER_API_KEY"] == "openrouter-secret")
        #expect(plan.environment["OPENAI_API_KEY"] == "openrouter-secret")
        #expect(plan.environment["OPENAI_BASE_URL"] == "https://openrouter.ai/api/v1")
        #expect(plan.environment["UNSELECTED_API_KEY"] == nil)
        #expect(store.loadedNames == [
            try CredentialName(validating: "MINIMAX_API_KEY"),
            try CredentialName(validating: "OPENROUTER_API_KEY"),
        ])
        #expect(store.loadAllCallCount == 0)
    }

    @Test func profileConflictFailsBeforeReadingAnySecret() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("envlatch-profile-conflict-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let endpointStore = EndpointProfileStore(fileURL: root.appendingPathComponent("endpoint-profiles.json"))
        for (provider, credential, baseURL) in [
            ("First", "FIRST_API_KEY", "https://first.example.com"),
            ("Second", "SECOND_API_KEY", "https://second.example.com"),
        ] {
            try endpointStore.upsert(
                EndpointProfile(
                    providerName: provider,
                    credentialName: CredentialName(validating: credential),
                    contract: .anthropic,
                    baseURL: baseURL
                )
            )
        }
        let launchStore = LaunchProfileStore(fileURL: root.appendingPathComponent("launch-profiles.json"))
        try launchStore.upsert(
            LaunchProfile(
                name: "Conflict",
                credentialNames: [
                    try CredentialName(validating: "FIRST_API_KEY"),
                    try CredentialName(validating: "SECOND_API_KEY"),
                ]
            )
        )
        let store = RecordingSecretStore(
            names: [
                try CredentialName(validating: "FIRST_API_KEY"),
                try CredentialName(validating: "SECOND_API_KEY"),
            ],
            values: ["FIRST_API_KEY": "first", "SECOND_API_KEY": "second"]
        )
        let application = makeApplication(
            store: store,
            environment: ["PATH": "/usr/bin:/bin"],
            endpointProfileStore: endpointStore,
            launchProfileStore: launchStore
        )

        #expect(throws: LaunchProfileError.self) {
            try application.prepareRun(profile: "Conflict", program: "true", arguments: [])
        }
        #expect(store.loadedNames.isEmpty)
        #expect(store.loadAllCallCount == 0)
    }

    @Test func pairsAnyNamedHostWithoutReadingCredentials() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("envlatch-pair-\(UUID().uuidString)", isDirectory: true)
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
                executableURL: URL(fileURLWithPath: "/Applications/EnvLatch.app/Contents/MacOS/EnvLatch"),
                linkURL: URL(fileURLWithPath: "/tmp/missing-envlatch"),
                pairScriptURL: URL(fileURLWithPath: "/Applications/EnvLatch.app/Contents/Resources/pair-agents.sh")
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
        endpointProfileStore: EndpointProfileStore? = nil,
        launchProfileStore: LaunchProfileStore? = nil
    ) -> CLIApplication {
        CLIApplication(
            store: store,
            environment: environment,
            inspector: InstallationInspector(
                executableURL: URL(fileURLWithPath: "/Applications/EnvLatch.app/Contents/MacOS/EnvLatch"),
                linkURL: URL(fileURLWithPath: "/tmp/missing-envlatch")
            ),
            endpointProfileStore: endpointProfileStore ?? EndpointProfileStore(
                fileURL: URL(fileURLWithPath: "/tmp/envlatch-missing-profiles-\(UUID().uuidString).json")
            ),
            launchProfileStore: launchProfileStore ?? LaunchProfileStore(
                fileURL: URL(fileURLWithPath: "/tmp/envlatch-missing-launch-profiles-\(UUID().uuidString).json")
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
