import CryptoKit
import Darwin
import Foundation
import Testing
@testable import EnvLatchCore

@_silgen_name("fork")
private func transferAcceptanceFork() -> pid_t

/// Explicit opt-in helper for two actual Macs. It cannot select the production vault.
@Suite("Synthetic two-Mac transfer acceptance", .serialized)
struct TransferNativeAcceptanceTests {
    @available(macOS 14.0, *)
    @Test(.enabled(if: ProcessInfo.processInfo.environment["ENVLATCH_TRANSFER_ACCEPTANCE_MODE"] != nil))
    func nativeTransferAcceptance() throws {
        let environment = ProcessInfo.processInfo.environment
        let mode = try #require(environment["ENVLATCH_TRANSFER_ACCEPTANCE_MODE"])
        print("native_pid=\(getpid())")
        let runID = try #require(environment["ENVLATCH_TRANSFER_ACCEPTANCE_RUN_ID"])
        _ = try #require(UUID(uuidString: runID))
        let rootPath = try #require(environment["ENVLATCH_TRANSFER_ACCEPTANCE_ROOT"])
        let root = URL(fileURLWithPath: rootPath, isDirectory: true)
        let service = "dev.envlatch.transfer.acceptance.\(runID.lowercased())"
        let name = try CredentialName(validating: "ENVLATCH_TRANSFER_SENTINEL_TOKEN")
        let unselected = try CredentialName(validating: "ENVLATCH_TRANSFER_UNSELECTED_TOKEN")
        let store = KeychainSecretStore(service: service)
        let identityStore = KeychainTransferIdentityStore(service: service + ".identity")

        if mode == "scan" {
            let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey])
            var noValue = true
            var noStaging = true
            if let files {
                for case let file as URL in files {
                    if try file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
                        let bytes = try Data(contentsOf: file)
                        noValue = noValue && bytes.range(of: Data(Self.syntheticSentinel.utf8)) == nil
                        noStaging = noStaging && file.pathExtension == "json"
                    }
                }
            }
            #expect(noValue)
            #expect(noStaging)
            print("native_no_synthetic_value_in_public_metadata=\(noValue)")
            print("native_no_unexpected_staging_files=\(noStaging)")
            return
        }

        if mode == "cleanup" {
            try store.delete(name: name)
            try store.delete(name: unselected)
            try KeychainSecretStore(service: service + ".identity")
                .delete(name: CredentialName(validating: "ENVLATCH_TRANSFER_PRIVATE_KEY"))
            #expect(try store.listNames().isEmpty)
            #expect(try KeychainSecretStore(service: service + ".identity").listNames().isEmpty)
            print("native_cleanup=empty_owned_namespace")
            return
        }

        let identity = try identityStore.loadOrCreate()
        if mode == "identity" {
            print("native_public_key=\(identity.publicKey.base64EncodedString())")
            print("native_fingerprint=\(identity.fingerprint)")
            print("native_service=\(service)")
            return
        }
        if mode == "seed" {
            #expect(try store.listNames().isEmpty)
            try store.create(name: name, value: Self.syntheticSentinel)
            try store.create(name: unselected, value: "public-unselected-acceptance-fixture")
            print("native_seed=two_synthetic_accounts")
            return
        }
        if mode == "verify" {
            try verifySelectedChild(store: store, name: name, unselected: unselected, root: root)
            print("native_source_or_target_exact=true")
            return
        }

        let peerKeyText = try #require(environment["ENVLATCH_TRANSFER_PEER_PUBLIC_KEY"])
        let peerKey = try #require(Data(base64Encoded: peerKeyText))
        let peerAddress = try #require(environment["ENVLATCH_TRANSFER_PEER_ADDRESS"])
        let portText = try #require(environment["ENVLATCH_TRANSFER_ACCEPTANCE_PORT"])
        let port = try #require(UInt16(portText))
        let peer = try TransferPeer(name: "Native Synthetic Peer", publicKey: peerKey, address: peerAddress, port: port)
        let metadata = TransferMetadataStore(directoryURL: root.appendingPathComponent("metadata"))
        do { #expect(try metadata.peer(named: peer.name) == peer) }
        catch TransferError.untrustedPeer { try metadata.pin(peer: peer) }
        let operationText = try #require(environment["ENVLATCH_TRANSFER_ACCEPTANCE_OPERATION"])
        let operation = try #require(UUID(uuidString: operationText))
        let receiving = mode == "receive"
        let binding = try TransferBinding(operationID: operation, credentialName: name.rawValue,
            sourceFingerprint: receiving ? peer.fingerprint : identity.fingerprint,
            targetFingerprint: receiving ? identity.fingerprint : peer.fingerprint)
        let session = TransferSession(identity: identity, peer: peer, metadata: metadata, secrets: store,
            consent: { request in
                // This proves Core's real channel and Keychain path, not production terminal approval.
                let exact = request.binding == binding && request.peer == peer
                print("native_consent=injected_test_exact_binding")
                return exact
            })

        let result: TransferRecord
        if receiving {
            let address = try #require(environment["ENVLATCH_TRANSFER_BIND_ADDRESS"])
            let listener = try TransferTCPListener(address: address, port: port,
                expectedPeerAddress: peerAddress, timeout: 45)
            defer { listener.close() }
            print("native_listener=ready")
            fflush(stdout)
            let connection = try listener.accept()
            defer { connection.close() }
            result = try session.receive(binding: binding, connection: connection)
        } else {
            #expect(mode == "send")
            let connection = try TransferTCPConnection.connect(address: peerAddress, port: port, timeout: 45)
            defer { connection.close() }
            result = try session.send(binding: binding, connection: connection)
        }
        #expect(result.binding == binding)
        #expect(result.state == .committed)
        #expect(result.status == "committed")
        print("native_operation=\(operation.uuidString)")
        print("native_result=\(result.status)")
        print("native_bound_peer=\(peer.fingerprint)")
        if receiving {
            #expect(try store.listNames() == [name])
            print("native_target_only_selected=true")
            try verifySelectedChild(store: store, name: name, unselected: unselected, root: root)
        }
    }

    private static let syntheticSentinel = "public-synthetic-envlatch-two-mac-acceptance-v1"

    private func verifySelectedChild(store: KeychainSecretStore, name: CredentialName,
                                     unselected: CredentialName, root: URL) throws {
        let application = CLIApplication(store: store, environment: ["PATH": "/usr/bin:/bin"],
            endpointProfileStore: EndpointProfileStore(fileURL: root.appendingPathComponent("endpoints.json")),
            launchProfileStore: LaunchProfileStore(fileURL: root.appendingPathComponent("groups.json")),
            stdout: { _ in }, stderr: { _ in })
        let expectedDigest = SHA256.hash(data: Data(Self.syntheticSentinel.utf8))
            .map { String(format: "%02x", $0) }.joined()
        let probe = """
        import hashlib, os, sys
        exact = hashlib.sha256(os.environ.get(sys.argv[1], '').encode()).hexdigest() == sys.argv[3]
        absent = sys.argv[2] not in os.environ
        print('native_selected_exact=' + str(exact).lower())
        print('native_unselected_absent=' + str(absent).lower())
        sys.exit(0 if exact and absent else 1)
        """
        let plan = try application.prepareRun(selections: [name.rawValue], program: "/usr/bin/python3",
            arguments: ["-c", probe, name.rawValue, unselected.rawValue, expectedDigest])
        var descriptors = [Int32](repeating: 0, count: 2)
        #expect(pipe(&descriptors) == 0)
        let child = transferAcceptanceFork()
        #expect(child >= 0)
        if child == 0 {
            close(descriptors[0])
            _ = dup2(descriptors[1], STDOUT_FILENO)
            _ = dup2(descriptors[1], STDERR_FILENO)
            close(descriptors[1])
            CommandRunner.execute(plan)
        }
        close(descriptors[1])
        var receipt = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)
        while true {
            let count = read(descriptors[0], &buffer, buffer.count)
            if count <= 0 { break }
            receipt.append(contentsOf: buffer.prefix(Int(count)))
        }
        close(descriptors[0])
        var status: Int32 = 0
        #expect(waitpid(child, &status, 0) == child)
        #expect(status == 0)
        print("native_reaped_child_pid=\(child)")
        let output = String(decoding: receipt, as: UTF8.self)
        #expect(output.contains("native_selected_exact=true"))
        #expect(output.contains("native_unselected_absent=true"))
        #expect(!output.contains(Self.syntheticSentinel))
        print(output, terminator: "")
    }
}
