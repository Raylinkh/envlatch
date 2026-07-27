import Testing
@testable import EnvLatchCore

@Suite("AK-3 and AK-6 CLI parsing")
struct CLIParserTests {
    @Test func parsesSafeCommands() throws {
        #expect(try CLIParser.parse(["list"]) == .list)
        #expect(try CLIParser.parse(["profiles"]) == .profiles)
        #expect(try CLIParser.parse(["groups"]) == .profiles)
        #expect(try CLIParser.parse(["doctor"]) == .doctor)
        #expect(try CLIParser.parse(["version"]) == .version)
        #expect(try CLIParser.parse(["--version"]) == .version)
        #expect(try CLIParser.parse(["pair", "Codex"]) == .pair(name: "Codex"))
        #expect(
            try CLIParser.parse(["pair", "Build", "Mac"])
                == .pair(name: "Build Mac")
        )
        #expect(
            try CLIParser.parse(["run", "--", "codex", "--model", "gpt-5.6"])
                == .run(selections: nil, program: "codex", arguments: ["--model", "gpt-5.6"])
        )
        #expect(
            try CLIParser.parse(["run", "--using", "MiniMax Anthropic", "--", "claude"])
                == .run(selections: ["MiniMax Anthropic"], program: "claude", arguments: [])
        )
        #expect(
            try CLIParser.parse([
                "run",
                "--using", "OPENAI_API_KEY",
                "--using", "Backend Tools",
                "--",
                "npm", "test",
            ]) == .run(
                selections: ["OPENAI_API_KEY", "Backend Tools"],
                program: "npm",
                arguments: ["test"]
            )
        )
        #expect(
            try CLIParser.parse([
                "groups", "create", "Backend Tools",
                "--using", "OPENAI_API_KEY",
                "--using", "GITHUB_TOKEN",
            ]) == .createGroup(
                name: "Backend Tools",
                credentialNames: ["OPENAI_API_KEY", "GITHUB_TOKEN"]
            )
        )
    }

    @Test(arguments: [
        [String](),
        ["unknown"],
        ["run"],
        ["run", "codex"],
        ["run", "--"],
        ["run", "--using"],
        ["run", "--using", "MiniMax"],
        ["run", "--using", "MiniMax", "--"],
        ["run", "--using", "MiniMax", "Anthropic", "--", "claude"],
        ["pair"],
        ["list", "extra"],
        ["profiles", "extra"],
        ["groups", "extra"],
        ["groups", "create"],
        ["groups", "create", "Backend"],
        ["groups", "create", "--using", "OPENAI_API_KEY"],
        ["groups", "create", "Backend", "--using"],
        ["groups", "create", "Backend", "--using", "OPENAI_API_KEY", "extra"],
        ["version", "extra"],
        ["--version", "extra"],
    ])
    func rejectsAmbiguousInput(_ arguments: [String]) {
        #expect(throws: CLIParseError.self) {
            try CLIParser.parse(arguments)
        }
    }
}
