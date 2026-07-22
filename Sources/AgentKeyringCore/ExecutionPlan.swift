import Darwin
import Foundation

public enum ExecutionPlanError: Error, Equatable, LocalizedError, Sendable {
    case emptyCredentials
    case containsNul(field: String)

    public var errorDescription: String? {
        switch self {
        case .emptyCredentials:
            "No credentials are saved. Add at least one key in AgentKeyring before launching a command."
        case .containsNul(let field):
            "\(field) contains an invalid NUL character."
        }
    }
}

public struct ExecutionPlan: Equatable, Sendable {
    public let executable: String
    public let arguments: [String]
    public let environment: [String: String]

    public static func make(
        resolvedExecutable: String,
        originalProgram: String,
        arguments: [String],
        inheritedEnvironment: [String: String],
        credentials: [String: String]
    ) throws -> ExecutionPlan {
        guard !credentials.isEmpty else {
            throw ExecutionPlanError.emptyCredentials
        }
        guard !resolvedExecutable.utf8.contains(0) else {
            throw ExecutionPlanError.containsNul(field: "Executable path")
        }
        guard !originalProgram.utf8.contains(0), arguments.allSatisfy({ !$0.utf8.contains(0) }) else {
            throw ExecutionPlanError.containsNul(field: "Command argument")
        }

        var environment = inheritedEnvironment
        for (rawName, value) in credentials {
            let name = try CredentialName(validating: rawName)
            try CredentialName.validateValue(value)
            environment[name.rawValue] = value
        }

        return ExecutionPlan(
            executable: resolvedExecutable,
            arguments: [originalProgram] + arguments,
            environment: environment
        )
    }
}

public enum CommandRunner {
    public static func execute(_ plan: ExecutionPlan) -> Never {
        let argumentStorage = plan.arguments.map { strdup($0) }
        let environmentStorage = plan.environment
            .sorted(by: { $0.key < $1.key })
            .map { strdup("\($0.key)=\($0.value)") }

        defer {
            argumentStorage.forEach { free($0) }
            environmentStorage.forEach { free($0) }
        }

        var argumentPointers = argumentStorage + [nil]
        var environmentPointers = environmentStorage + [nil]

        _ = plan.executable.withCString { executablePointer in
            execve(executablePointer, &argumentPointers, &environmentPointers)
        }

        let failure = errno
        let message = String(cString: strerror(failure))
        FileHandle.standardError.write(Data("AgentKeyring could not launch \(plan.executable): \(message)\n".utf8))
        exit(failure == ENOENT ? 127 : 126)
    }
}
