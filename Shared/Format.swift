import Foundation

// The same wording as hackertube.org.

/// "4:48" or "1:02:03".
func formatDuration(_ s: Int?) -> String {
    guard let s, s > 0 else { return "" }
    let h = s / 3600, m = s % 3600 / 60, x = s % 60
    return h > 0 ? String(format: "%d:%02d:%02d", h, m, x) : String(format: "%d:%02d", m, x)
}

private func oneDecimal(_ x: Double) -> String {
    let s = String(format: "%.1f", x)
    return s.hasSuffix(".0") ? String(s.dropLast(2)) : s
}

/// "43.9M views".
func formatViews(_ n: Int64?) -> String {
    guard let n else { return "" }
    if n >= 1_000_000_000 { return "\(oneDecimal(Double(n) / 1e9))B views" }
    if n >= 1_000_000 { return "\(oneDecimal(Double(n) / 1e6))M views" }
    if n >= 1_000 { return "\(Int((Double(n) / 1e3).rounded()))K views" }
    return "\(n) views"
}

private let isoParser: ISO8601DateFormatter = ISO8601DateFormatter()

/// "13 years ago".
func formatAgo(_ iso: String?) -> String {
    guard let iso, let date = isoParser.date(from: iso) else { return "" }
    let s = Date().timeIntervalSince(date)
    for (unit, sec) in [("year", 31_536_000.0), ("month", 2_592_000), ("week", 604_800), ("day", 86_400)] {
        let n = Int(floor(s / sec))
        if n >= 1 { return "\(n) \(unit)\(n > 1 ? "s" : "") ago" }
    }
    return "today"
}

/// "6 hr 32 min" or "45 min".
func formatHours(_ m: Int?) -> String {
    let m = m ?? 0
    return m >= 60 ? "\(m / 60) hr \(m % 60) min" : "\(m) min"
}

func formatMB(_ b: Int) -> String {
    b >= 1_000_000 ? String(format: "%.1f MB", Double(b) / 1e6) : "\(max(1, Int((Double(b) / 1e3).rounded()))) KB"
}

func formatNumber(_ n: Int) -> String {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.locale = Locale(identifier: "en_US")
    return f.string(from: NSNumber(value: n)) ?? "\(n)"
}

extension Video {
    /// "43.9M views • 13 years ago".
    var stats: String { [formatViews(views), formatAgo(published)].filter { !$0.isEmpty }.joined(separator: " • ") }

    /// "5 HN recommenders · recommended in 6 months, 2014–2024".
    var recLine: String {
        let hn = hn ?? HNStats()
        let span = "\(hn.first ?? "")–\(hn.last ?? "")"
        if let r = hn.recommenders, r > 0 {
            let m = hn.recMonths ?? 0
            return "\(r) HN recommender\(r == 1 ? "" : "s") · recommended in \(m) month\(m == 1 ? "" : "s"), \(span)"
        }
        return "Cited \(hn.mentions ?? 0)× on HN, \(span)"
    }

    /// "43.9M views · 13 years ago · talk · evergreen".
    var topLine: String {
        [formatViews(views), formatAgo(published), contentType ?? "", shelfLife ?? ""]
            .filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

extension Comment {
    /// The comment text with HTML-like whitespace collapsing, as the site renders it.
    var collapsedText: String {
        (text ?? "").split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }
    var year: String { String((ym ?? "").prefix(4)) }
}
