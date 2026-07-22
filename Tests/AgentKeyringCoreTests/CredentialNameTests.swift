import Foundation
import Testing
@testable import AgentKeyringCore

@Suite("AK-1 credential validation")
struct CredentialNameTests {
    @Test(arguments: [
        "OPENAI_API_KEY",
        "ANTHROPIC_API_KEY",
        "GITHUB_TOKEN",
        "AWS_SECRET_ACCESS_KEY",
        "DATABASE_PASSWORD",
        "SIGNING_PRIVATE_KEY",
    ])
    func acceptsCredentialShapedNames(_ rawValue: String) throws {
        #expect(try CredentialName(validating: rawValue).rawValue == rawValue)
    }

    @Test(arguments: [
        "",
        "openai_api_key",
        "9TOKEN",
        "PATH",
        "HOME",
        "NODE_OPTIONS",
        "DYLD_API_KEY",
        "LD_SERVICE_TOKEN",
        "OPENAI_KEY",
        "API-KEY",
    ])
    func rejectsUnsafeOrNonCredentialNames(_ rawValue: String) {
        #expect(throws: CredentialValidationError.self) {
            try CredentialName(validating: rawValue)
        }
    }

    @Test func rejectsEmptyAndNulValues() {
        #expect(throws: CredentialValidationError.self) {
            try CredentialName.validateValue("")
        }
        #expect(throws: CredentialValidationError.self) {
            try CredentialName.validateValue("abc\0def")
        }
        #expect(throws: Never.self) {
            try CredentialName.validateValue("sk-disposable")
        }
    }
}
