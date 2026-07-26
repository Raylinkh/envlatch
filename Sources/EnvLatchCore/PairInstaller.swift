import Foundation

public protocol PairInstalling {
    func install(scriptURL: URL, environment: [String: String]) throws
}

public enum PairInstallationError: Error, LocalizedError, Sendable {
    case scriptMissing(String)
    case scriptFailed(Int32)

    public var errorDescription: String? {
        switch self {
        case .scriptMissing(let path):
            "Pairing script is missing or not executable: \(path)"
        case .scriptFailed(let status):
            "Pairing setup failed with exit status \(status)."
        }
    }
}

public struct PairScriptInstaller: PairInstalling {
    public init() {}

    public func install(scriptURL: URL, environment: [String: String]) throws {
        guard FileManager.default.isExecutableFile(atPath: scriptURL.path) else {
            throw PairInstallationError.scriptMissing(scriptURL.path)
        }

        let process = Process()
        process.executableURL = scriptURL
        process.environment = environment
        process.standardOutput = FileHandle.standardOutput
        process.standardError = FileHandle.standardError
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw PairInstallationError.scriptFailed(process.terminationStatus)
        }
    }
}
