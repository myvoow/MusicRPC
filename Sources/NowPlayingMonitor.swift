import Foundation

struct NowPlaying: Decodable, Equatable {
    var title: String
    var artist: String?
    var album: String?
    var bundleIdentifier: String
    var playing: Bool
    var durationMicros: Double?
    var elapsedTimeMicros: Double?
    var timestampEpochMicros: Double?

    func artworkURL() async -> String? {
        struct ITunes: Decodable { let results: [Song]; struct Song: Decodable { let trackName: String, artworkUrl100: String } }
        struct Deezer: Decodable {
            let data: [Song]
            struct Song: Decodable { let title: String, album: Album }
            struct Album: Decodable { let cover_xl: String? }
        }
        let term = [artist, title].compactMap { $0 }.joined(separator: " ")
        let country = Locale.current.region?.identifier ?? "US"
        if let r: ITunes = await Self.get("https://itunes.apple.com/search", ["term": term, "entity": "song", "limit": "5", "country": country]),
           let song = r.results.first(where: { isTitle($0.trackName) }) {
            return song.artworkUrl100.replacingOccurrences(of: "100x100bb", with: "512x512bb")
        }
        let r: Deezer? = await Self.get("https://api.deezer.com/search", ["q": term, "limit": "5"])
        return r?.data.first(where: { isTitle($0.title) })?.album.cover_xl
    }

    private func isTitle(_ name: String) -> Bool { name.caseInsensitiveCompare(title) == .orderedSame }

    private static func get<T: Decodable>(_ base: String, _ query: [String: String]) async -> T? {
        var url = URLComponents(string: base)!
        url.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let (data, _) = try? await URLSession.shared.data(for: URLRequest(url: url.url!, timeoutInterval: 5)) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}

final class NowPlayingMonitor {
    private let onChange: @MainActor (NowPlaying?) -> Void

    init(onChange: @escaping @MainActor (NowPlaying?) -> Void) {
        self.onChange = onChange
        start()
    }

    static func parse(_ line: Data) -> NowPlaying? {
        struct Line: Decodable { let payload: NowPlaying }
        return (try? JSONDecoder().decode(Line.self, from: line).payload)
            .flatMap { $0.playing && $0.bundleIdentifier == "com.apple.Music" ? $0 : nil }
    }

    private func start() {
        let res = Bundle.main.resourceURL!
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = [
            res.appending(path: "mediaremote-adapter.pl").path,
            res.appending(path: "MediaRemoteAdapter.framework").path,
            "stream", "--no-diff", "--no-artwork", "--micros", "--debounce=300",
        ]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.terminationHandler = { [weak self] _ in self?.restart() }
        do { try process.run() } catch { return restart() }

        Task {
            for try await line in pipe.fileHandleForReading.bytes.lines {
                await onChange(Self.parse(Data(line.utf8)))
            }
        }
    }

    private func restart() {
        Task { @MainActor in onChange(nil) }
        DispatchQueue.global().asyncAfter(deadline: .now() + 3) { [weak self] in self?.start() }
    }
}
