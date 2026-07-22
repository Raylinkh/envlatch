import Testing
@testable import AgentKeyringCore

@Suite("AK-3 and AK-6 CLI parsing")
struct CLIParserTests {
    @Test func parsesSafeCommands() throws {
        #expect(try CLIParser.parse(["list"]) == .list)
        #expect(try CLIParser.parse(["doctor"]) == .doctor)
        #expect(
            try CLIParser.parse(["run", "--", "codex", "--model", "gpt-5.6"])
                == .run(program: "codex", arguments: ["--model", "gpt-5.6"])
        )
    }

    @Test(arguments: [
        [String](),
        ["unknown"],
        ["run"],
        ["run", "codex"],
        ["run", "--"],
        ["list", "extra"],
    ])
    func rejectsAmbiguousInput(_ arguments: [String]) {
        #expect(throws: CLIParseError.self) {
            try CLIParser.parse(arguments)
        }
    }
}
