import Darwin
import Foundation

public enum ExecutionPlanError: Error, Equatable, LocalizedError, Sendable {
    case emptyCredentials
    case containsNul(field: String)

    public var errorDescription: String? {
        switch self {
        case .emptyCredentials:
            "No credentials are saved. Add at least one key in EnvLatch before launching a command."
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
        credentials: [String: String],
        configuration: [String: String] = [:]
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
        for (name, value) in configuration {
            guard isSafeEnvironmentName(name), !value.utf8.contains(0) else {
                throw ExecutionPlanError.containsNul(field: "Environment configuration")
            }
            environment[name] = value
        }

        return ExecutionPlan(
            executable: resolvedExecutable,
            arguments: [originalProgram] + arguments,
            environment: environment
        )
    }

    private static func isSafeEnvironmentName(_ value: String) -> Bool {
        guard let first = value.utf8.first,
              (65...90).contains(first) || first == 95,
              !value.hasPrefix("DYLD_"),
              !value.hasPrefix("LD_") else {
            return false
        }
        return value.utf8.dropFirst().allSatisfy {
            (65...90).contains($0) || (48...57).contains($0) || $0 == 95
        }
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
        FileHandle.standardError.write(Data("EnvLatch could not launch \(plan.executable): \(message)\n".utf8))
        exit(failure == ENOENT ? 127 : 126)
    }
}
