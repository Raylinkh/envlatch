import CryptoKit
import Darwin
import Foundation
import Testing
@testable import EnvLatchCore

@_silgen_name("fork")
private func systemFork() -> pid_t

@Suite("AK-3 real direct execution", .serialized)
struct CommandRunnerIntegrationTests {
    @Test func preservesPIDLiteralArgumentsAndExactEnvironmentWithoutLeakingValue() throws {
        let canary = "disposable-\(UUID().uuidString)"
        let digest = SHA256.hash(data: Data(canary.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        let literal = "literal * [x] ; should-not-run"
        let probe = """
        import hashlib, os, sys
        value = os.environ.get("ENVLATCH_EXEC_TEST_TOKEN", "")
        print(f"exact_value={hashlib.sha256(value.encode()).hexdigest() == sys.argv[1]}")
        print(f"literal_argument={sys.argv[2] == 'literal * [x] ; should-not-run'}")
        print(f"pid={os.getpid()}")
        """
        let plan = ExecutionPlan(
            executable: "/usr/bin/python3",
            arguments: ["python3", "-c", probe, digest, literal],
            environment: ["ENVLATCH_EXEC_TEST_TOKEN": canary]
        )

        var descriptors = [Int32](repeating: 0, count: 2)
        #expect(pipe(&descriptors) == 0)
        let childPID = systemFork()
        #expect(childPID >= 0)

        if childPID == 0 {
            close(descriptors[0])
            _ = dup2(descriptors[1], STDOUT_FILENO)
            _ = dup2(descriptors[1], STDERR_FILENO)
            close(descriptors[1])
            CommandRunner.execute(plan)
        }

        close(descriptors[1])
        var receipt = Data()
        var buffer = [UInt8](repeating: 0, count: 1_024)
        while true {
            let count = read(descriptors[0], &buffer, buffer.count)
            if count <= 0 { break }
            receipt.append(contentsOf: buffer.prefix(Int(count)))
        }
        close(descriptors[0])

        var childStatus: Int32 = 0
        #expect(waitpid(childPID, &childStatus, 0) == childPID)
        #expect(childStatus == 0)

        let output = String(decoding: receipt, as: UTF8.self)
        #expect(output.contains("exact_value=True"))
        #expect(output.contains("literal_argument=True"))
        #expect(output.contains("pid=\(childPID)"))
        #expect(!output.contains(canary))
    }
}
