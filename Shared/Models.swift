import Foundation

// The JSON shapes of the hackertube.org API (decoded with convertFromSnakeCase).

struct Video: Codable, Identifiable, Hashable {
    let vid: String
    let title: String
    var channel: String?
    var published: String?
    var durationS: Int?
    var views: Int64?
    var summary: String?
    var whyHn: String?
    var contentType: String?
    var shelfLife: String?
    var tags: [String]?
    var categories: [CategoryRef]?
    var hn: HNStats?
    /// The topic a search result matched on, when it matched on meaning rather than words.
    var via: String?
    /// A playlist's note on this video.
    var note: String?
    /// Why the Home feed picked this video ("An HN classic", ...).
    var reason: String?

    var id: String { vid }
    static func == (a: Video, b: Video) -> Bool { a.vid == b.vid }
    func hash(into h: inout Hasher) { h.combine(vid) }
}

struct CategoryRef: Codable, Hashable {
    let id: String
    let name: String
    var areaName: String?
}

struct HNStats: Codable, Hashable {
    var mentions: Int?
    var recommenders: Int?
    var recMonths: Int?
    var first: String?
    var last: String?
}

struct Comment: Codable, Identifiable, Hashable {
    let id: Int
    let author: String
    var ym: String?
    var story: String?
    var stance: String?
    var text: String?
}

struct VideoPage: Codable {
    let video: Video
    let comments: [Comment]
}

struct SearchResults: Codable {
    var weak: Bool?
    let results: [Video]
}

struct Area: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let count: Int
    let categories: [Category]
}

struct Category: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let count: Int
}

struct PlaylistCard: Codable, Identifiable, Hashable {
    let slug: String
    let title: String
    var pitch: String?
    var tier: String?
    var minutes: Int?
    var count: Int?
    var cover: [String]?
    var id: String { slug }
}

struct Playlist: Codable {
    let slug: String
    let title: String
    var intro: String?
    var minutes: Int?
    let videos: [Video]
}

struct Stats: Codable {
    let videos: Int
    let comments: Int
    var categories: Int?
    var areas: Int?
    var firstYear: String?
    var lastYear: String?
}

struct ExportInfo: Codable {
    struct File: Codable, Hashable {
        let name: String
        let bytes: Int
        var rows: Int?
    }
    var files: [File]?
    var zip: File?
    var videos: Int?
    var mentions: Int?
    var generated: String?
}

/// How an HN comment uses the video, worded as on the site.
let stanceLabels: [String: String] = [
    "strong_rec": "Strongly recommends", "rec": "Recommends", "reference": "Cites",
    "joke": "Joke", "critical": "Critical",
]
