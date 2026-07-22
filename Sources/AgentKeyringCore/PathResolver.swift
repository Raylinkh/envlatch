import Darwin
import Foundation

public enum PathResolutionError: Error, Equatable, LocalizedError, Sendable {
    case emptyProgram
    case programContainsNul
    case missingInheritedPath
    case emptyPathSegment
    case notExecutable(String)
    case notFound(String)

    public var errorDescription: String? {
        switch self {
        case .emptyProgram:
            "The program name is empty."
        case .programContainsNul:
            "The program name contains an invalid NUL character."
        case .missingInheritedPath:
            "The caller did not provide PATH, so AgentKeyring cannot resolve a bare program name."
        case .emptyPathSegment:
            "PATH contains an empty segment. Use an explicit directory instead of the current-directory shorthand."
        case .notExecutable(let path):
            "The selected program is not an executable regular file: \(path)"
        case .notFound(let program):
            "Program not found in the caller's PATH: \(program)"
        }
    }
}

public enum PathResolver {
    public static func resolve(program: String, inheritedPath: String?) throws -> String {
        guard !program.isEmpty else {
            throw PathResolutionError.emptyProgram
        }
        guard !program.utf8.contains(0) else {
            throw PathResolutionError.programContainsNul
        }

        if program.contains("/") {
            let absolutePath = absoluteStandardizedPath(program)
            guard isExecutableRegularFile(absolutePath) else {
                throw PathResolutionError.notExecutable(absolutePath)
            }
            return absolutePath
        }

        guard let inheritedPath, !inheritedPath.isEmpty else {
            throw PathResolutionError.missingInheritedPath
        }

        let directories = inheritedPath.split(separator: ":", omittingEmptySubsequences: false)
        guard directories.allSatisfy({ !$0.isEmpty }) else {
            throw PathResolutionError.emptyPathSegment
        }

        for directory in directories {
            let candidate = URL(fileURLWithPath: String(directory), isDirectory: true)
                .appendingPathComponent(program)
                .standardizedFileURL.path
            if isExecutableRegularFile(candidate) {
                return candidate
            }
        }

        throw PathResolutionError.notFound(program)
    }

    private static func absoluteStandardizedPath(_ path: String) -> String {
        if path.hasPrefix("/") {
            return URL(fileURLWithPath: path).standardizedFileURL.path
        }
        return URL(
            fileURLWithPath: path,
            relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        ).standardizedFileURL.path
    }

    private static func isExecutableRegularFile(_ path: String) -> Bool {
        guard access(path, X_OK) == 0,
              let attributes = try? FileManager.default.attributesOfItem(atPath: path),
              let type = attributes[.type] as? FileAttributeType
        else {
            return false
        }
        return type == .typeRegular
    }
}
