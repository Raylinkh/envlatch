import Foundation

public enum PersistenceNamespace {
    // These identifiers shipped locally before the public EnvLatch rename. Keeping one
    // namespace avoids copying secret values or splitting durable state across stores.
    public static let keychainService = "dev.agentkeyring.secrets"
    public static let applicationSupportDirectoryName = "AgentKeyring"

    public static var applicationSupportDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support", isDirectory: true)
            .appendingPathComponent(applicationSupportDirectoryName, isDirectory: true)
    }
}
