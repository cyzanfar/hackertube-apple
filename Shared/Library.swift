import Foundation
import SwiftUI

/// Likes, dislikes, Watch later and history — kept on the device only, like the website's localStorage.
/// They travel to the API only to shape the Home feed.
@Observable
final class Library {
    static let shared = Library()
    private let d = UserDefaults.standard

    var likes: [String] { didSet { d.set(likes, forKey: "likes") } }
    var dislikes: [String] { didSet { d.set(dislikes, forKey: "dislikes") } }
    /// Videos opened, newest last; kept out of the Home feed.
    var seen: [String] { didSet { d.set(seen, forKey: "seen") } }
    /// Saved for later, newest last.
    var later: [String] { didSet { d.set(later, forKey: "later") } }
    /// "Video frames" setting: a frame from the middle of the video instead of the uploader's thumbnail.
    var frames: Bool { didSet { d.set(frames, forKey: "frames") } }
    /// Apple TV: play inside HackerTube (true) or hand videos to the YouTube app.
    var playInApp: Bool { didSet { d.set(playInApp, forKey: "playInApp") } }
    /// nil follows the system; "light" / "dark" once toggled.
    var theme: String? { didSet { d.set(theme, forKey: "theme") } }

    /// A fresh seed on every launch: relaunching (or pulling to refresh) rerolls Home.
    private(set) var seed = Library.newSeed()

    private init() {
        likes = d.stringArray(forKey: "likes") ?? []
        dislikes = d.stringArray(forKey: "dislikes") ?? []
        seen = d.stringArray(forKey: "seen") ?? []
        later = d.stringArray(forKey: "later") ?? []
        frames = d.object(forKey: "frames") as? Bool ?? true
        theme = d.string(forKey: "theme")
        playInApp = d.object(forKey: "playInApp") as? Bool ?? true
    }

    private static func newSeed() -> String { String(Int.random(in: 0..<1_000_000_000)) }
    func reroll() { seed = Library.newSeed() }

    var colorScheme: ColorScheme? { theme == "dark" ? .dark : theme == "light" ? .light : nil }

    func isLiked(_ vid: String) -> Bool { likes.contains(vid) }
    func isDisliked(_ vid: String) -> Bool { dislikes.contains(vid) }
    func isLater(_ vid: String) -> Bool { later.contains(vid) }

    func toggleLike(_ vid: String) {
        if let i = likes.firstIndex(of: vid) { likes.remove(at: i) } else {
            likes.append(vid)
            dislikes.removeAll { $0 == vid }
        }
    }

    func toggleDislike(_ vid: String) {
        if let i = dislikes.firstIndex(of: vid) { dislikes.remove(at: i) } else {
            dislikes.append(vid)
            likes.removeAll { $0 == vid }
        }
    }

    @discardableResult
    func toggleLater(_ vid: String) -> Bool {
        if let i = later.firstIndex(of: vid) { later.remove(at: i); return false }
        later.append(vid)
        return true
    }

    func markSeen(_ vid: String) {
        seen = Array((seen.filter { $0 != vid } + [vid]).suffix(200))
    }

    func clearHistory() { seen = [] }

    func toggleTheme(system: ColorScheme) {
        let current = colorScheme ?? system
        theme = current == .dark ? "light" : "dark"
    }
}
