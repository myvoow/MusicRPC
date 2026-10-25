import Foundation

struct Activity: Encodable, Equatable {
    struct Timestamps: Encodable, Equatable { var start: Int; var end: Int? }
    struct Assets: Encodable, Equatable { var large_image: String; var large_text: String? }
    var type = 2
    var details: String
    var state: String
    var timestamps: Timestamps?
    var assets: Assets?

    init(_ np: NowPlaying, artwork: String?) {
        details = Self.clip(np.title)
        state = Self.clip(np.artist ?? "")
        assets = artwork.map { Assets(large_image: $0, large_text: np.album.map(Self.clip)) }
        if let ts = np.timestampEpochMicros, let elapsed = np.elapsedTimeMicros {
            let start = Int(((ts - elapsed) / 1_000_000).rounded()) * 1000
            timestamps = Timestamps(start: start, end: np.durationMicros.map { start + Int($0 / 1000) })
        }
    }

    static func clip(_ s: String) -> String { s.count < 2 ? s + "\u{2800}\u{2800}" : String(s.prefix(128)) }
}

final class DiscordIPC: @unchecked Sendable {
    private var fd: Int32 = -1
    private var lastSent: Activity?? = nil

    func setActivity(_ activity: Activity?, clientID: String) -> Bool {
        if fd >= 0, !isAlive() { disconnect() }
        if fd >= 0, lastSent == .some(activity) { return true }
        if fd < 0, !connect(clientID: clientID) { return false }

        struct Args: Encodable {
            let pid: Int32, activity: Activity?
            func encode(to e: Encoder) throws {
                var c = e.container(keyedBy: CodingKeys.self)
                try c.encode(pid, forKey: .pid)
                try c.encode(activity, forKey: .activity)
            }
            enum CodingKeys: CodingKey { case pid, activity }
        }
        struct Command: Encodable { var cmd = "SET_ACTIVITY", args: Args, nonce = UUID().uuidString }
        let json = try! JSONEncoder().encode(Command(args: Args(pid: getpid(), activity: activity)))
        guard request(op: 1, json) != nil else { return false }
        lastSent = .some(activity)
        return true
    }

    func disconnect() {
        if fd >= 0 { close(fd) }
        fd = -1
        lastSent = nil
    }

    static func frame(op: Int32, _ json: Data) -> Data {
        var data = Data()
        withUnsafeBytes(of: op.littleEndian) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: Int32(json.count).littleEndian) { data.append(contentsOf: $0) }
        return data + json
    }

    static func isValid(clientID: String) -> Bool { clientID.count >= 17 && UInt64(clientID) != nil }

    private func connect(clientID: String) -> Bool {
        guard Self.isValid(clientID: clientID) else { return false }
        for i in 0..<10 {
            let dir = ProcessInfo.processInfo.environment["TMPDIR"] ?? NSTemporaryDirectory()
            let path = (dir as NSString).appendingPathComponent("discord-ipc-\(i)")
            let s = socket(AF_UNIX, SOCK_STREAM, 0)
            var on: Int32 = 1, timeout = timeval(tv_sec: 5, tv_usec: 0)
            setsockopt(s, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<Int32>.size))
            setsockopt(s, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
            var addr = sockaddr_un()
            addr.sun_family = sa_family_t(AF_UNIX)
            withUnsafeMutableBytes(of: &addr.sun_path) { dst in
                path.utf8CString.withUnsafeBytes { dst.copyBytes(from: $0.prefix(dst.count - 1)) }
            }
            let connected = withUnsafePointer(to: &addr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    Darwin.connect(s, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) == 0
                }
            }
            guard connected else { close(s); continue }
            fd = s
            if request(op: 0, try! JSONSerialization.data(withJSONObject: ["v": 1, "client_id": clientID]))?.op == 1 {
                return true
            }
            disconnect()
        }
        return false
    }

    private func request(op: Int32, _ json: Data) -> (op: Int32, json: Data)? {
        let out = Self.frame(op: op, json)
        let written = out.withUnsafeBytes { write(fd, $0.baseAddress, $0.count) }
        guard written == out.count, let header = read(8) else { disconnect(); return nil }
        let replyOp = header.withUnsafeBytes { Int32(littleEndian: $0.loadUnaligned(as: Int32.self)) }
        let length = header.withUnsafeBytes { Int32(littleEndian: $0.loadUnaligned(fromByteOffset: 4, as: Int32.self)) }
        guard length >= 0, let body = read(Int(length)) else { disconnect(); return nil }
        return (replyOp, body)
    }

    private func read(_ count: Int) -> Data? {
        var data = Data(count: count), got = 0
        while got < count {
            let n = data.withUnsafeMutableBytes { Darwin.read(fd, $0.baseAddress! + got, count - got) }
            guard n > 0 else { return nil }
            got += n
        }
        return data
    }

    private func isAlive() -> Bool {
        var byte: UInt8 = 0
        return recv(fd, &byte, 1, MSG_PEEK | MSG_DONTWAIT) != 0
    }
}
