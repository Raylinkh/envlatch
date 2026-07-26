import EnvLatchCore
import Darwin
import SwiftUI

@main
enum EnvLatchMain {
    static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst())
        if arguments.isEmpty {
            EnvLatchGUI.main()
        } else {
            exit(CLIApplication().run(arguments: arguments))
        }
    }
}

struct EnvLatchGUI: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("EnvLatch") {
            VaultView()
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 720, height: 600)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.activate(ignoringOtherApps: true)
    }
}
