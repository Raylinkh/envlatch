import Darwin
import Foundation

@main
enum TransferAcceptanceMain {
    static func main() {
        do {
            guard #available(macOS 14.0, *) else { throw TransferError.invalidInput }
            let harness = NativeTransferAcceptanceHarness()
            if ProcessInfo.processInfo.environment["ENVLATCH_TRANSFER_TERMINAL_TEST"] != nil {
                try harness.runTerminal()
            } else {
                try harness.run()
            }
        } catch KeychainStoreError.osStatus(_, let status) {
            print("native_error=keychain_osstatus_\(status)")
            exit(1)
        } catch let error as TransferError {
            print("native_error=\(String(describing: error))")
            exit(1)
        } catch {
            fputs("Synthetic transfer acceptance failed.\n", stderr)
            exit(1)
        }
    }
}
