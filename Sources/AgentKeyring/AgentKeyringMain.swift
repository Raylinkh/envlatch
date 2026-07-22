import AgentKeyringCore
import Darwin
import SwiftUI

@main
enum AgentKeyringMain {
    static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst())
        if arguments.isEmpty {
            AgentKeyringGUI.main()
        } else {
            exit(CLIApplication().run(arguments: arguments))
        }
    }
}

struct AgentKeyringGUI: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("AgentKeyring") {
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
