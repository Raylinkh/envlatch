import Testing
@testable import AgentKeyringCore

@Suite("AK-3 direct execution plan")
struct ExecutionPlanTests {
    @Test func overlaysCredentialsAndPreservesLiteralArguments() throws {
        let plan = try ExecutionPlan.make(
            resolvedExecutable: "/usr/bin/true",
            originalProgram: "true",
            arguments: ["a b", "$(touch should-not-run)", "*.swift"],
            inheritedEnvironment: [
                "PATH": "/usr/bin:/bin",
                "GITHUB_TOKEN": "wrong-inherited-value",
                "LANG": "en_US.UTF-8",
            ],
            credentials: [
                "GITHUB_TOKEN": "keychain-value",
                "OPENAI_API_KEY": "second-keychain-value",
            ]
        )

        #expect(plan.executable == "/usr/bin/true")
        #expect(plan.arguments == ["true", "a b", "$(touch should-not-run)", "*.swift"])
        #expect(plan.environment["PATH"] == "/usr/bin:/bin")
        #expect(plan.environment["LANG"] == "en_US.UTF-8")
        #expect(plan.environment["GITHUB_TOKEN"] == "keychain-value")
        #expect(plan.environment["OPENAI_API_KEY"] == "second-keychain-value")
    }

    @Test func rejectsEmptyOrUnsafeCredentialSets() {
        #expect(throws: ExecutionPlanError.self) {
            try ExecutionPlan.make(
                resolvedExecutable: "/usr/bin/true",
                originalProgram: "true",
                arguments: [],
                inheritedEnvironment: [:],
                credentials: [:]
            )
        }
        #expect(throws: CredentialValidationError.self) {
            try ExecutionPlan.make(
                resolvedExecutable: "/usr/bin/true",
                originalProgram: "true",
                arguments: [],
                inheritedEnvironment: [:],
                credentials: ["PATH": "/malicious"]
            )
        }
    }
}
