import Foundation
import Testing

@Suite("Synthetic two-Mac transfer acceptance", .serialized)
struct TransferNativeAcceptanceTests {
    @available(macOS 14.0, *)
    @Test(.enabled(if: ProcessInfo.processInfo.environment["ENVLATCH_TRANSFER_ACCEPTANCE_MODE"] != nil))
    func nativeTransferAcceptance() throws {
        try NativeTransferAcceptanceHarness().run()
    }
}
