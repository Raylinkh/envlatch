import Foundation
import Testing
@testable import EnvLatchCore

@Suite("Paired transfer public action parsing")
struct TransferCommandTests {
    private let operation = "901B3780-B39D-4DB5-814B-D05833D0B9FC"

    @Test func acceptsTheSelectedKeyTransferEntrySequence() throws {
        for action in ["send", "status"] {
            _ = try CLIParser.parse([
                "transfer", action, "--peer", "Studio Synthetic",
                "--using", "ENVLATCH_TRANSFER_TOKEN", "--operation", operation,
            ])
        }
        _ = try CLIParser.parse([
            "transfer", "receive", "--peer", "Mac Synthetic",
            "--using", "ENVLATCH_TRANSFER_TOKEN", "--operation", operation,
            "--bind", "100.85.4.100",
        ])
        _ = try CLIParser.parse(["transfer", "identity"])
    }

    @Test func rejectsIncompleteOrBroadTransferActions() {
        let invalid = [
            ["transfer"],
            ["transfer", "send"],
            ["transfer", "send", "--peer", "Studio Synthetic", "--operation", operation],
            ["transfer", "send", "--using", "ENVLATCH_TRANSFER_TOKEN", "--operation", operation],
            ["transfer", "send", "--peer", "Studio Synthetic", "--using", "ENVLATCH_TRANSFER_TOKEN"],
            ["transfer", "send", "--peer", "Studio Synthetic", "--using", "ENVLATCH_TRANSFER_TOKEN", "--operation", "not-a-uuid"],
            ["transfer", "send", "--peer", "Studio Synthetic", "--using", "ENVLATCH_TRANSFER_TOKEN", "--operation", operation, "--yes"],
            ["transfer", "send", "--peer", "Studio Synthetic", "--using", "ENVLATCH_TRANSFER_TOKEN", "--using", "ENVLATCH_OTHER_TOKEN", "--operation", operation],
            ["transfer", "export", "ENVLATCH_TRANSFER_TOKEN"],
            ["transfer", "identity", "extra"],
        ]
        for arguments in invalid {
            #expect(throws: (any Error).self) { try CLIParser.parse(arguments) }
        }
    }
}
