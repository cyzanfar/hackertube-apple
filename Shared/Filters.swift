import Foundation

/// The site's filters, YouTube-style. Each option is one URL parameter on the site; here one key in a dictionary.
/// Hidden gems: recommended on HN but under 100k YouTube views. Evergreen: drops news-only videos.
struct Filters: Hashable {
    private(set) var values: [String: String] = [:]

    init(_ values: [String: String] = [:]) {
        self.values = values.filter { !$0.value.isEmpty }
    }

    subscript(_ key: String) -> String {
        get { values[key] ?? "" }
        set { values[key] = newValue.isEmpty ? nil : newValue }
    }

    var params: [(String, String)] { filterKeys.compactMap { k in values[k].map { (k, $0) } } }
    /// Any filter other than the sort order.
    var filtering: Bool { values.keys.contains { $0 != "sort" } }

    /// Choosing an option sets it; choosing the active one clears it.
    func toggling(_ key: String, _ value: String) -> Filters {
        var f = self
        f[key] = self[key] == value ? "" : value
        return f
    }

    static let longs = Filters(["dur": "xlong"])
}

struct FilterOption: Hashable {
    let key: String
    let value: String
    let label: String
}

struct FilterGroup: Hashable {
    let title: String
    let options: [FilterOption]
}

private func opts(_ key: String, _ pairs: [(String, String)]) -> [FilterOption] {
    pairs.map { FilterOption(key: key, value: $0.0, label: $0.1) }
}

let allFilterGroups: [FilterGroup] = [
    FilterGroup(title: "Upload date", options: opts("date", [("year", "Past year"), ("2020s", "2020s"), ("2010s", "2010s"), ("2000s", "2000s")])),
    FilterGroup(title: "Type", options: opts("type", [("talk", "Talk"), ("lecture", "Lecture"), ("explainer", "Explainer"),
        ("tutorial", "Tutorial"), ("documentary", "Documentary"), ("interview", "Interview"), ("demo", "Demo"),
        ("commentary", "Commentary"), ("comedy", "Comedy"), ("music", "Music")])),
    FilterGroup(title: "Duration", options: opts("dur", [("short", "Under 4 minutes"), ("medium", "4–20 minutes"),
        ("long", "20–60 minutes"), ("xlong", "Over 1 hour")])),
    FilterGroup(title: "Features", options: [FilterOption(key: "gems", value: "1", label: "Hidden gems"),
        FilterOption(key: "evergreen", value: "1", label: "Evergreen only")]),
    FilterGroup(title: "Sort by", options: opts("sort", [("", "Relevance"), ("recent", "Recently recommended"),
        ("date", "Upload date"), ("old", "Oldest first"), ("views", "View count"), ("liked", "Like ratio"),
        ("hn", "Most recommended")])),
]

let filterKeys: [String] = {
    var seen = Set<String>()
    return allFilterGroups.flatMap { $0.options.map(\.key) }.filter { seen.insert($0).inserted }
}()

/// On topic pages there is no query, so the default order is "Best first" (most recommended),
/// and that option is folded into it.
func filterGroups(listing: Bool) -> [FilterGroup] {
    guard listing else { return allFilterGroups }
    return allFilterGroups.map { g in
        guard g.title == "Sort by" else { return g }
        return FilterGroup(title: g.title, options: g.options.filter { $0.value != "hn" }.map {
            $0.value.isEmpty ? FilterOption(key: $0.key, value: "", label: "Best first") : $0
        })
    }
}

/// The chips for the active filters.
func activeFilterOptions(_ f: Filters, listing: Bool) -> [FilterOption] {
    filterGroups(listing: listing).flatMap { $0.options }.filter { !$0.value.isEmpty && f[$0.key] == $0.value }
}
