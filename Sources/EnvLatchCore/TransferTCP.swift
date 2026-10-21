import Darwin
import Foundation

/// Length-prefixed encrypted messages over one bounded, owned TCP connection.
public final class TransferTCPConnection: TransferConnection {
    private var descriptor: Int32
    private let deadline: UInt64
    public static let maximumFrameBytes = 131_072

    fileprivate init(descriptor: Int32, deadline: UInt64) throws {
        self.descriptor = descriptor
        self.deadline = deadline
        var enabled: Int32 = 1
        guard setsockopt(descriptor, SOL_SOCKET, SO_NOSIGPIPE, &enabled, socklen_t(MemoryLayout.size(ofValue: enabled))) == 0,
              fcntl(descriptor, F_SETFL, O_NONBLOCK) == 0,
              fcntl(descriptor, F_SETFD, FD_CLOEXEC) == 0 else {
            _ = Darwin.close(descriptor)
            self.descriptor = -1
            throw TransferError.transport
        }
    }

    deinit { close() }
    public func close() {
        if descriptor >= 0 { _ = Darwin.close(descriptor); descriptor = -1 }
    }

    public static func connect(address: String, port: UInt16, timeout: TimeInterval = 120) throws -> TransferTCPConnection {
        var endpoint = try numericAddress(address, port: port)
        let deadline = try transferDeadline(timeout)
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { throw TransferError.transport }
        let connection = try TransferTCPConnection(descriptor: fd, deadline: deadline)
        do {
            let result = withUnsafePointer(to: &endpoint) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
            }
            guard result == 0 || errno == EINPROGRESS else { throw TransferError.transport }
            if result != 0 {
                try waitForSocket(fd, events: Int16(POLLOUT), deadline: connection.deadline)
                var error: Int32 = 0
                var length = socklen_t(MemoryLayout.size(ofValue: error))
                guard getsockopt(fd, SOL_SOCKET, SO_ERROR, &error, &length) == 0, error == 0 else {
                    throw TransferError.transport
                }
            }
            return connection
        } catch { connection.close(); throw error }
    }

    public func send(_ frame: Data) throws {
        guard !frame.isEmpty, frame.count <= Self.maximumFrameBytes else { throw TransferError.frameTooLarge }
        var size = UInt32(frame.count).bigEndian
        try withUnsafeBytes(of: &size) { try writeBytes($0) }
        try frame.withUnsafeBytes { try writeBytes($0) }
    }

    public func receive() throws -> Data {
        let header = try readBytes(count: 4)
        let count = header.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        guard count > 0, Int(count) <= Self.maximumFrameBytes else { throw TransferError.frameTooLarge }
        return try readBytes(count: Int(count))
    }

    private func writeBytes(_ bytes: UnsafeRawBufferPointer) throws {
        var offset = 0
        while offset < bytes.count {
            try waitForSocket(descriptor, events: Int16(POLLOUT), deadline: deadline)
            let count = Darwin.send(descriptor, bytes.baseAddress!.advanced(by: offset), bytes.count - offset, 0)
            if count < 0, errno == EINTR || errno == EAGAIN { continue }
            guard count > 0 else { throw TransferError.transport }
            offset += count
        }
    }

    private func readBytes(count: Int) throws -> Data {
        var data = Data(count: count)
        try data.withUnsafeMutableBytes { bytes in
            var offset = 0
            while offset < bytes.count {
                try waitForSocket(descriptor, events: Int16(POLLIN), deadline: deadline)
                let count = Darwin.recv(descriptor, bytes.baseAddress!.advanced(by: offset), bytes.count - offset, 0)
                if count < 0, errno == EINTR || errno == EAGAIN { continue }
                guard count > 0 else { throw TransferError.transport }
                offset += count
            }
        }
        return data
    }
}

public final class TransferTCPListener {
    private var descriptor: Int32
    private let deadline: UInt64
    private let expectedPeer: in_addr
    public private(set) var localPort: UInt16 = 0

    public init(address: String, port: UInt16, expectedPeerAddress: String, timeout: TimeInterval = 120) throws {
        var endpoint = try numericAddress(address, port: port)
        self.expectedPeer = try numericAddress(expectedPeerAddress, port: 0).sin_addr
        self.deadline = try transferDeadline(timeout)
        self.descriptor = socket(AF_INET, SOCK_STREAM, 0)
        guard descriptor >= 0 else { throw TransferError.transport }
        do {
            // Rebind after this one-shot receiver's previous connection enters TIME_WAIT.
            // SO_REUSEPORT is intentionally absent: a live listener remains exclusive.
            var reuseAddress: Int32 = 1
            guard setsockopt(descriptor, SOL_SOCKET, SO_REUSEADDR, &reuseAddress,
                             socklen_t(MemoryLayout.size(ofValue: reuseAddress))) == 0,
                  fcntl(descriptor, F_SETFL, O_NONBLOCK) == 0,
                  fcntl(descriptor, F_SETFD, FD_CLOEXEC) == 0 else { throw TransferError.transport }
            let bound = withUnsafePointer(to: &endpoint) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.bind(descriptor, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
            }
            guard bound == 0, Darwin.listen(descriptor, 1) == 0 else { throw TransferError.transport }
            var length = socklen_t(MemoryLayout<sockaddr_in>.size)
            let named = withUnsafeMutablePointer(to: &endpoint) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(descriptor, $0, &length) }
            }
            guard named == 0 else { throw TransferError.transport }
            self.localPort = UInt16(bigEndian: endpoint.sin_port)
        } catch { _ = Darwin.close(descriptor); descriptor = -1; throw error }
    }

    deinit { close() }
    public func close() {
        if descriptor >= 0 { _ = Darwin.close(descriptor); descriptor = -1 }
    }

    public func accept() throws -> TransferTCPConnection {
        defer { close() }
        try waitForSocket(descriptor, events: Int16(POLLIN), deadline: deadline)
        var remote = sockaddr_in()
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let fd = withUnsafeMutablePointer(to: &remote) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.accept(descriptor, $0, &length) }
        }
        guard fd >= 0 else { throw TransferError.transport }
        guard remote.sin_addr.s_addr == expectedPeer.s_addr else {
            _ = Darwin.close(fd)
            throw TransferError.untrustedPeer
        }
        return try TransferTCPConnection(descriptor: fd, deadline: deadline)
    }
}

private func numericAddress(_ address: String, port: UInt16) throws -> sockaddr_in {
    var endpoint = sockaddr_in()
    endpoint.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    endpoint.sin_family = sa_family_t(AF_INET)
    endpoint.sin_port = port.bigEndian
    guard inet_pton(AF_INET, address, &endpoint.sin_addr) == 1,
          endpoint.sin_addr.s_addr != INADDR_ANY else { throw TransferError.invalidInput }
    return endpoint
}

private func transferDeadline(_ timeout: TimeInterval) throws -> UInt64 {
    guard timeout.isFinite, timeout > 0, timeout <= 300 else { throw TransferError.invalidInput }
    return DispatchTime.now().uptimeNanoseconds + UInt64(timeout * 1_000_000_000)
}

private func waitForSocket(_ descriptor: Int32, events: Int16, deadline: UInt64) throws {
    guard descriptor >= 0 else { throw TransferError.transport }
    while true {
        let now = DispatchTime.now().uptimeNanoseconds
        guard now < deadline else { throw TransferError.timeout }
        let milliseconds = Int32(min((deadline - now) / 1_000_000 + 1, UInt64(Int32.max)))
        var descriptorState = pollfd(fd: descriptor, events: events, revents: 0)
        let result = poll(&descriptorState, 1, milliseconds)
        if result < 0, errno == EINTR { continue }
        guard result >= 0 else { throw TransferError.transport }
        guard result > 0 else { throw TransferError.timeout }
        // POLLIN can accompany HUP while a final frame is still readable.
        guard descriptorState.revents & events != 0 else { throw TransferError.transport }
        return
    }
}
