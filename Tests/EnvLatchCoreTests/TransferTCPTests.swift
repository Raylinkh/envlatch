import Darwin
import Foundation
import Testing
@testable import EnvLatchCore

@Suite("Bounded native transfer TCP framing", .serialized)
struct TransferTCPTests {
    @Test func adapterCarriesExactFramesAndRejectsOversizeBeforeSend() throws {
        let listener = try TransferTCPListener(address: "127.0.0.1", port: 0,
            expectedPeerAddress: "127.0.0.1", timeout: 2)
        defer { listener.close() }
        let client = try TransferTCPConnection.connect(address: "127.0.0.1", port: listener.localPort, timeout: 2)
        defer { client.close() }
        let server = try listener.accept()
        defer { server.close() }
        let frame = Data("public-encrypted-frame-fixture".utf8)
        try client.send(frame)
        #expect(try server.receive() == frame)
        #expect(throws: TransferError.frameTooLarge) { try client.send(Data()) }
        #expect(throws: TransferError.frameTooLarge) {
            try client.send(Data(repeating: 0, count: TransferTCPConnection.maximumFrameBytes + 1))
        }
    }

    @Test(arguments: [UInt32(0), UInt32(131_073), UInt32.max])
    func maliciousLengthHeaderIsRefusedWithoutPayload(length: UInt32) throws {
        let listener = try TransferTCPListener(address: "127.0.0.1", port: 0,
            expectedPeerAddress: "127.0.0.1", timeout: 2)
        defer { listener.close() }
        let descriptor = try connectRaw(port: listener.localPort)
        defer { _ = Darwin.close(descriptor) }
        let server = try listener.accept()
        defer { server.close() }
        var header = length.bigEndian
        let sent = withUnsafeBytes(of: &header) { Darwin.send(descriptor, $0.baseAddress, $0.count, 0) }
        #expect(sent == 4)
        #expect(throws: TransferError.frameTooLarge) { try server.receive() }
    }

    @Test func wrongNumericPeerAddressIsRefusedAtAccept() throws {
        let listener = try TransferTCPListener(address: "127.0.0.1", port: 0,
            expectedPeerAddress: "127.0.0.2", timeout: 2)
        defer { listener.close() }
        let descriptor = try connectRaw(port: listener.localPort)
        defer { _ = Darwin.close(descriptor) }
        #expect(throws: TransferError.untrustedPeer) { try listener.accept() }
    }

    @Test func acceptedPeerThatSendsNoFrameHitsTheSharedDeadline() throws {
        let listener = try TransferTCPListener(address: "127.0.0.1", port: 0,
            expectedPeerAddress: "127.0.0.1", timeout: 0.2)
        defer { listener.close() }
        let descriptor = try connectRaw(port: listener.localPort)
        defer { _ = Darwin.close(descriptor) }
        let server = try listener.accept()
        defer { server.close() }
        #expect(throws: TransferError.timeout) { try server.receive() }
    }

    private func connectRaw(port: UInt16) throws -> Int32 {
        let descriptor = socket(AF_INET, SOCK_STREAM, 0)
        guard descriptor >= 0 else { throw TransferError.transport }
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = port.bigEndian
        guard inet_pton(AF_INET, "127.0.0.1", &address.sin_addr) == 1 else {
            _ = Darwin.close(descriptor)
            throw TransferError.invalidInput
        }
        let result = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(descriptor, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard result == 0 else { _ = Darwin.close(descriptor); throw TransferError.transport }
        return descriptor
    }
}
