import Foundation

enum APIError: LocalizedError {
    case http(Int)
    var code: Int { if case .http(let c) = self { return c }; return 0 }
    var errorDescription: String? { "\(code)" }
}

/// The JSON API behind hackertube.org — the same endpoints the website calls.
enum API {
    static let base = URL(string: "https://hackertube.org/api/")!

    static let session: URLSession = {
        let c = URLSessionConfiguration.default
        c.urlCache = URLCache(memoryCapacity: 32 << 20, diskCapacity: 256 << 20)
        c.timeoutIntervalForRequest = 60
        return URLSession(configuration: c)
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    // keep "+" and friends from being read as spaces by the server
    private static let allowed: CharacterSet = {
        var s = CharacterSet.alphanumerics
        s.insert(charactersIn: "-._~,")
        return s
    }()

    static func url(_ path: String, _ params: [(String, String)] = []) -> URL {
        var comps = URLComponents(url: base.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        let q = params.filter { !$0.1.isEmpty }
            .map { "\($0.0)=\($0.1.addingPercentEncoding(withAllowedCharacters: allowed) ?? "")" }
            .joined(separator: "&")
        if !q.isEmpty { comps.percentEncodedQuery = q }
        return comps.url!
    }

    static func get<T: Decodable>(_ path: String, _ params: [(String, String)] = []) async throws -> T {
        let (data, resp) = try await session.data(from: url(path, params))
        if let h = resp as? HTTPURLResponse, !(200..<300).contains(h.statusCode) { throw APIError.http(h.statusCode) }
        return try decoder.decode(T.self, from: data)
    }

    /// The Home feed: picks shaped by likes, without dislikes and already-seen videos.
    static func feed(_ lib: Library, offset: Int, n: Int = 36) async throws -> [Video] {
        try await get("feed", [
            ("like", lib.likes.joined(separator: ",")),
            ("dislike", lib.dislikes.joined(separator: ",")),
            ("seen", lib.seen.joined(separator: ",")),
            ("seed", lib.seed), ("offset", "\(offset)"), ("n", "\(n)"),
        ])
    }

    /// Every video matching the filters (cat, area, dur, sort, ...), best first.
    static func list(_ params: [(String, String)], offset: Int, n: Int = 36) async throws -> [Video] {
        try await get("list", params + [("offset", "\(offset)"), ("n", "\(n)")])
    }

    static func search(_ q: String, _ params: [(String, String)] = []) async throws -> SearchResults {
        try await get("search", [("q", q)] + params)
    }

    static func video(_ vid: String) async throws -> VideoPage { try await get("video", [("vid", vid)]) }
    static func related(_ vid: String) async throws -> [Video] { try await get("related", [("vid", vid), ("n", "20")]) }

    /// The videos for `vids`, in the same order.
    static func docs(_ vids: [String]) async throws -> [Video] {
        vids.isEmpty ? [] : try await get("docs", [("vids", vids.joined(separator: ","))])
    }

    private static var areasCache: [Area]?
    @MainActor static func areas() async throws -> [Area] {
        if let a = areasCache { return a }
        let a: [Area] = try await get("browse")
        areasCache = a
        return a
    }

    static func playlists() async throws -> [PlaylistCard] { try await get("playlists") }
    static func playlist(_ slug: String) async throws -> Playlist { try await get("playlist", [("slug", slug)]) }
    static func stats() async throws -> Stats { try await get("stats") }
    static func export() async throws -> ExportInfo { try await get("export") }
}

/// "Play all on YouTube": YouTube's watch_videos link turns up to 50 ids into a temporary playlist.
func playAllURL(_ vids: [String]) -> URL? {
    var seen = Set<String>()
    let ids = vids.filter { seen.insert($0).inserted }.prefix(50)
    guard !ids.isEmpty else { return nil }
    return URL(string: "https://www.youtube.com/watch_videos?video_ids=\(ids.joined(separator: ","))")
}

func youtubeURL(_ vid: String) -> URL { URL(string: "https://www.youtube.com/watch?v=\(vid)")! }
func hnURL(_ id: Int) -> URL { URL(string: "https://news.ycombinator.com/item?id=\(id)")! }
