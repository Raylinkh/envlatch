import Foundation
import Testing

@Suite("Production transfer terminal consent", .serialized)
struct TransferTerminalConsentTests {
    @available(macOS 14.0, *)
    @Test(.enabled(if: ProcessInfo.processInfo.environment["ENVLATCH_TRANSFER_TERMINAL_TEST"] != nil))
    func terminalConsentNative() throws {
        try NativeTransferAcceptanceHarness().runTerminal()
    }
}
