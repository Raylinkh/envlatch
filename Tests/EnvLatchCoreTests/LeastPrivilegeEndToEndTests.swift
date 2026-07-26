import CryptoKit
import Darwin
import Foundation
import Testing
@testable import EnvLatchCore

@_silgen_name("fork")
private func endToEndFork() -> pid_t

@Suite("AK-3 least-privilege parser to real Keychain to exec", .serialized)
struct LeastPrivilegeEndToEndTests {
    @Test func twoSelectedOneUnselectedMappedLiteralAndPIDPreserved() throws {
        let service = "dev.envlatch.tests.\(UUID().uuidString)"
        let store = KeychainSecretStore(service: service)
        let first = try CredentialName(validating: "ENVLATCH_SELECTED_A_TOKEN")
        let second = try CredentialName(validating: "ENVLATCH_SELECTED_B_TOKEN")
        let unselected = try CredentialName(validating: "ENVLATCH_UNSELECTED_TOKEN")
        let values = [
            first: "selected-a-\(UUID().uuidString)",
            second: "selected-b-\(UUID().uuidString)",
            unselected: "unselected-\(UUID().uuidString)",
        ]
        defer {
            for name in values.keys {
                try? store.delete(name: name)
            }
        }
        for (name, value) in values {
            try store.save(name: name, value: value)
        }

        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("envlatch-e2e-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let endpoints = EndpointProfileStore(fileURL: root.appendingPathComponent("endpoints.json"))
        try endpoints.upsert(
            EndpointProfile(
                providerName: "First",
                credentialName: first,
                contract: .anthropic,
                baseURL: "https://first.example.com",
                credentialEnvironmentName: CredentialName(validating: "FIRST_TARGET_TOKEN")
            )
        )
        try endpoints.upsert(
            EndpointProfile(
                providerName: "Second",
                credentialName: second,
                contract: .openAIResponses,
                baseURL: "https://second.example.com/v1",
                credentialEnvironmentName: CredentialName(validating: "SECOND_TARGET_TOKEN")
            )
        )
        let launches = LaunchProfileStore(fileURL: root.appendingPathComponent("launches.json"))
        try launches.upsert(
            LaunchProfile(name: "Integration", credentialNames: [first, second])
        )

        let probe = """
        import hashlib, os, sys
        def digest(name):
            return hashlib.sha256(os.environ.get(name, "").encode()).hexdigest()
        print(f"selected_a={digest('ENVLATCH_SELECTED_A_TOKEN') == sys.argv[1]}")
        print(f"alias_a={digest('FIRST_TARGET_TOKEN') == sys.argv[1]}")
        print(f"selected_b={digest('ENVLATCH_SELECTED_B_TOKEN') == sys.argv[2]}")
        print(f"alias_b={digest('SECOND_TARGET_TOKEN') == sys.argv[2]}")
        print(f"unselected_absent={'ENVLATCH_UNSELECTED_TOKEN' not in os.environ}")
        print(f"anthropic_base={os.environ.get('ANTHROPIC_BASE_URL') == 'https://first.example.com'}")
        print(f"openai_base={os.environ.get('OPENAI_BASE_URL') == 'https://second.example.com/v1'}")
        print(f"literal_argument={sys.argv[3] == 'literal * [x] ; unchanged'}")
        print(f"pid={os.getpid()}")
        """
        let application = CLIApplication(
            store: store,
            environment: ["PATH": "/usr/bin:/bin"],
            endpointProfileStore: endpoints,
            launchProfileStore: launches,
            stdout: { _ in },
            stderr: { _ in }
        )
        let arguments = [
            "run", "--using", "Integration", "--",
            "/usr/bin/python3", "-c", probe,
            digest(values[first]), digest(values[second]),
            "literal * [x] ; unchanged",
        ]
        let command = try CLIParser.parse(arguments)
        guard case .run(let profile, let program, let programArguments) = command else {
            Issue.record("Expected a parsed run command")
            return
        }
        let plan = try application.prepareRun(
            profile: profile,
            program: program,
            arguments: programArguments
        )

        var descriptors = [Int32](repeating: 0, count: 2)
        #expect(pipe(&descriptors) == 0)
        let childPID = endToEndFork()
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
        for expected in [
            "selected_a=True",
            "alias_a=True",
            "selected_b=True",
            "alias_b=True",
            "unselected_absent=True",
            "anthropic_base=True",
            "openai_base=True",
            "literal_argument=True",
            "pid=\(childPID)",
        ] {
            #expect(output.contains(expected))
        }
        for value in values.values {
            #expect(!output.contains(value))
        }
    }

    private func digest(_ value: String?) -> String {
        SHA256.hash(data: Data((value ?? "").utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
