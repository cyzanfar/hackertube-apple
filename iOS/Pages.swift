import SwiftUI

// MARK: - Filterable infinite grids (/, /browse, /a/<id>, /c/<id>)

struct ListingPage<Header: View>: View {
    var isHome = false
    var playable = true
    let base: [(String, String)]
    @ViewBuilder let header: (Filters) -> Header
    @State private var filters: Filters
    @State private var pager: Pager?
    @Environment(Library.self) private var lib
    @Environment(Router.self) private var router

    init(isHome: Bool = false, playable: Bool = true, base: [(String, String)] = [], initial: Filters = Filters(),
         @ViewBuilder header: @escaping (Filters) -> Header) {
        self.isHome = isHome
        self.playable = playable
        self.base = base
        self.header = header
        _filters = State(initialValue: initial)
    }

    var body: some View {
        PageScroll {
            header(filters)
            FilterBar(filters: filters, listing: true, playable: playable, vids: pager?.items.map(\.vid) ?? []) { f in
                // Home's filters lead to /browse (advanced search without a query)
                if isHome { router.push(.browse(f)) } else { filters = f }
            }
            if let pager { PagedGrid(pager: pager, filtering: filters.filtering) }
        }
        .onAppear { if pager?.key != AnyHashable(filters) { reload() } }
        .onChange(of: filters) { reload() }
        .refreshable {
            // like reloading the site: Home rerolls its mix
            if isHome { lib.reroll() }
            reload()
        }
    }

    private func reload() {
        let f = filters, base = base, home = isHome, lib = lib
        let p = Pager(key: AnyHashable(f)) { offset in
            home ? try await API.feed(lib, offset: offset) : try await API.list(base + f.params, offset: offset)
        }
        pager = p
        p.more()
    }
}

struct HomePage: View {
    var body: some View {
        ListingPage(isHome: true, playable: false) { _ in EmptyView() }
    }
}

struct BrowsePage: View {
    let initial: Filters
    var body: some View {
        ListingPage(initial: initial) { f in
            let longs = f["dur"] == "xlong"
            PageHead(title: longs ? "Longs" : "All videos",
                     sub: longs ? "Every video over an hour. The opposite of Shorts." : nil)
        }
    }
}

/// Loads /api/browse (cached) and finds what a page needs in it.
struct AreasLoader<Content: View>: View {
    @ViewBuilder let content: ([Area]) -> Content
    @State private var areas: [Area]?
    @State private var failed: String?
    var body: some View {
        Group {
            if let areas { content(areas) }
            else if let failed { PageScroll { StatusText(text: failed) } }
            else { PageScroll { StatusText(text: "Loading…") } }
        }
        .task {
            if areas == nil {
                do { areas = try await API.areas() } catch { failed = "Something went wrong (\(error.localizedDescription))." }
            }
        }
    }
}

struct AreaPage: View {
    let id: String
    @Environment(Router.self) private var router
    var body: some View {
        AreasLoader { areas in
            if let a = areas.first(where: { $0.id == id }) {
                ListingPage(base: [("area", id)]) { _ in
                    PageHead(title: a.name)
                    FlowLayout(spacing: 8) {
                        ForEach(a.categories) { c in Chip(title: c.name) { router.push(.category(c.id)) } }
                    }
                    .padding(.top, 12)
                }
            } else { PageScroll { StatusText(text: "Not found.") } }
        }
    }
}

struct CategoryPage: View {
    let id: String
    @Environment(Router.self) private var router
    var body: some View {
        AreasLoader { areas in
            if let a = areas.first(where: { $0.categories.contains { $0.id == id } }),
               let c = a.categories.first(where: { $0.id == id }) {
                ListingPage(base: [("cat", id)]) { _ in
                    PageHead(crumb: a.name, onCrumb: { router.push(.area(a.id)) }, title: c.name)
                }
            } else { PageScroll { StatusText(text: "Not found.") } }
        }
    }
}

// MARK: - /categories

struct CategoriesPage: View {
    @Environment(Router.self) private var router
    var body: some View {
        AreasLoader { areas in
            PageScroll(maxWidth: 1400) {
                PageHead(title: "Categories")
                FlowLayout(spacing: 8) {
                    Pill(title: "Recently recommended") { router.push(.browse(Filters(["sort": "recent"]))) }
                    Pill(title: "Longs") { router.push(.browse(.longs)) }
                    Pill(title: "Hidden gems") { router.push(.browse(Filters(["gems": "1"]))) }
                    Pill(title: "All videos") { router.push(.browse(Filters())) }
                }
                .padding(.top, 16).padding(.bottom, 4)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 16, alignment: .top)], spacing: 16) {
                    ForEach(areas) { a in AreaCard(area: a) }
                }
                .padding(.top, 16)
            }
        }
    }
}

struct AreaCard: View {
    let area: Area
    @Environment(Router.self) private var router
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { router.push(.area(area.id)) } label: {
                HStack(alignment: .firstTextBaseline) {
                    Text(area.name).font(.system(size: 16, weight: .semibold)).multilineTextAlignment(.leading)
                    Spacer(minLength: 8)
                    Text("\(area.count)").font(.system(size: 12)).foregroundStyle(HT.muted)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.bottom, 6)
            ForEach(area.categories) { c in
                Button { router.push(.category(c.id)) } label: {
                    HStack(alignment: .firstTextBaseline) {
                        Text(c.name).font(.system(size: 14)).multilineTextAlignment(.leading)
                        Spacer(minLength: 8)
                        Text("\(c.count)").font(.system(size: 12))
                    }
                    .foregroundStyle(HT.muted)
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(HT.bg2))
    }
}

// MARK: - /playlists and /p/<slug>

struct PlaylistsPage: View {
    @State private var playlists: [PlaylistCard]?
    var body: some View {
        PageScroll(maxWidth: 1400) {
            PageHead(title: "Playlists", sub: "Curated by Claude from what Hacker News recommends, each in a deliberate order.")
            if let playlists {
                if playlists.isEmpty {
                    Text("Coming soon.").font(.system(size: 14)).foregroundStyle(HT.muted).padding(.top, 4)
                }
                ForEach([("start", "Start here", "Broad, essential lists for your first visit."),
                         ("deep", "Deep dives", "One obsession each, for when you want to go down a rabbit hole.")], id: \.0) { tier, title, blurb in
                    let ps = playlists.filter { ($0.tier ?? "deep") == tier }
                    if !ps.isEmpty {
                        Text(title).font(.system(size: 20, weight: .bold)).padding(.top, 28).padding(.bottom, 2)
                        Text(blurb).font(.system(size: 14)).foregroundStyle(HT.muted).padding(.bottom, 14)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 16, alignment: .top)], spacing: 24) {
                            ForEach(ps) { PlaylistCardView(p: $0) }
                        }
                    }
                }
            } else {
                StatusText(text: "Loading…")
            }
        }
        .task { if playlists == nil { playlists = (try? await API.playlists()) ?? [] } }
    }
}

struct PlaylistPage: View {
    let slug: String
    @State private var pl: Playlist?
    @State private var failed = false
    @Environment(Router.self) private var router
    @Environment(\.narrow) private var narrow

    var body: some View {
        PageScroll(maxWidth: 1100) {
            if let pl {
                let info = VStack(alignment: .leading, spacing: 0) {
                    Button { router.setRoot(.playlists) } label: { Text("Playlists").font(.system(size: 14)).foregroundStyle(HT.muted) }
                        .buttonStyle(.plain)
                    Text(pl.title).font(.system(size: 28, weight: .bold)).lineSpacing(1).padding(.top, 4).padding(.bottom, 6)
                    Text("Curated by Claude · \(pl.videos.count) videos · \(formatHours(pl.minutes))")
                        .font(.system(size: 14)).foregroundStyle(HT.muted)
                    Text(pl.intro ?? "").ht(14, line: 22).padding(.vertical, 12)
                    PlayAllPill(vids: pl.videos.map(\.vid))
                }
                Group {
                    if narrow {
                        VStack(alignment: .leading, spacing: 16) { Mosaic(vids: pl.videos.map(\.vid)); info }
                            .padding(.top, 16)
                    } else {
                        HStack(alignment: .top, spacing: 24) { Mosaic(vids: pl.videos.map(\.vid)).frame(width: 360); info }
                            .padding(.top, 24)
                    }
                }
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(Array(pl.videos.enumerated()), id: \.element.vid) { i, v in
                        PlaylistRow(index: i + 1, video: v)
                    }
                }
                .padding(.top, 24)
            } else {
                StatusText(text: failed ? "Not found." : "Loading…")
            }
        }
        .task {
            guard pl == nil else { return }
            do { pl = try await API.playlist(slug) } catch { failed = true }
        }
    }
}

struct PlaylistRow: View {
    let index: Int
    let video: Video
    @Environment(Router.self) private var router
    @Environment(\.narrow) private var narrow

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if !narrow {
                Text("\(index)").font(.system(size: 14)).foregroundStyle(HT.muted)
                    .frame(width: 24, alignment: .trailing).padding(.top, 4)
            }
            Button { router.push(.watch(video.vid)) } label: {
                let info = VStack(alignment: .leading, spacing: 0) {
                    Text(video.title).ht(18, line: 26).lineLimit(2).multilineTextAlignment(.leading).padding(.bottom, 4)
                    Text([video.channel ?? "", video.stats].filter { !$0.isEmpty }.joined(separator: " · "))
                        .ht(14, line: 20).foregroundStyle(HT.muted)
                    Text(video.note ?? "").ht(14, line: 20).multilineTextAlignment(.leading).padding(.top, 8)
                }
                Group {
                    if narrow { VStack(alignment: .leading, spacing: 8) { Thumb(video: video); info } }
                    else { HStack(alignment: .top, spacing: 16) { Thumb(video: video).frame(width: 280); info } }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .videoMenu(video)
        }
    }
}

// MARK: - /liked /history /later

struct SavedPage: View {
    enum Kind { case liked, history, later }
    let kind: Kind
    @Environment(Library.self) private var lib
    @State private var videos: [Video]?
    @State private var loadedFor: [String]?

    private var vids: [String] {
        switch kind { case .liked: lib.likes; case .history: lib.seen; case .later: lib.later }
    }

    var body: some View {
        PageScroll {
            let title = switch kind { case .liked: "Liked videos"; case .history: "History"; case .later: "Watch later" }
            let empty = switch kind {
            case .liked: "Videos you like will show up here, and shape your Home feed."
            case .history: "Videos you open will show up here."
            case .later: "Save videos to watch later with the clock button on a thumbnail or on a video's page."
            }
            PageHead(title: title)
            if kind == .history && !lib.seen.isEmpty {
                Pill(title: "Clear all watch history") { lib.clearHistory() }.padding(.top, 8)
            }
            if let videos, !videos.isEmpty {
                PlayAllPill(vids: videos.map(\.vid)).padding(.top, 16)
                VideoGrid(videos: videos)
            } else if videos != nil {
                StatusText(text: empty)
            }
        }
        .task(id: vids) {
            // newest first
            let want = Array(vids.reversed())
            if loadedFor == want { return }
            if want.isEmpty { videos = []; loadedFor = want; return }
            // drop removed ones at once so un-saving feels instant
            if let v = videos { videos = v.filter { want.contains($0.vid) } }
            if let docs = try? await API.docs(want) { videos = docs; loadedFor = want }
            else if videos == nil { videos = [] }
        }
    }
}

// MARK: - /search/<q>

struct SearchPage: View {
    let query: String
    @State private var filters: Filters
    @State private var results: SearchResults?
    @State private var message: String?
    @State private var loadedKey: Filters?

    init(query: String, initial: Filters) {
        self.query = query
        _filters = State(initialValue: initial)
    }

    var body: some View {
        PageScroll {
            if let message { StatusText(text: message) }
            else if let results {
                FilterBar(filters: filters, vids: results.results.map(\.vid)) { filters = $0 }
                if results.weak == true {
                    Text(results.results.isEmpty ? "No videos match “\(query)” with these filters."
                         : "No strong matches for “\(query)”. Here are the closest videos.")
                        .font(.system(size: 14)).foregroundStyle(HT.muted).padding(.top, 16)
                }
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(results.results) { SearchRow(video: $0) }
                }
                .frame(maxWidth: 1100, alignment: .leading)
                .padding(.top, 16)
            } else {
                StatusText(text: "Searching…")
            }
        }
        .task(id: filters) {
            guard loadedKey != filters else { return }
            results = nil
            message = nil
            do {
                results = try await API.search(query, filters.params)
                loadedKey = filters
            } catch let e as APIError where e.code == 429 || e.code == 503 {
                message = "Lots of searches right now. Give it a minute and try again."
            } catch is CancellationError {
            } catch let e as URLError where e.code == .cancelled {
            } catch {
                message = "Something went wrong (\(error.localizedDescription))."
            }
        }
    }
}

// MARK: - /settings

struct SettingsPage: View {
    @Environment(Library.self) private var lib
    var body: some View {
        @Bindable var lib = lib
        PageScroll(maxWidth: nil) {
            PageHead(title: "Settings")
            Button { lib.frames.toggle() } label: {
                HStack(alignment: .top, spacing: 24) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Show video frames instead of thumbnails").font(.system(size: 15, weight: .medium))
                        Text("YouTube thumbnails are designed by uploaders to grab your attention: big faces, arrows, shouting text. With this on, every video is shown with a frame from the middle of the video instead, so you see what it actually looks like. Turn it off to see the original thumbnails.")
                            .ht(14, line: 21).foregroundStyle(HT.muted).multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 0)
                    SiteSwitch(on: lib.frames).padding(.top, 2)
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(HT.bg2))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 24)
            .frame(maxWidth: 720, alignment: .leading)
            .accessibilityAddTraits(.isToggle)
            .accessibilityValue(lib.frames ? "On" : "Off")
        }
    }
}

/// The site's 36×20 switch.
struct SiteSwitch: View {
    let on: Bool
    var body: some View {
        Capsule().fill(on ? HT.good : HT.bg3)
            .frame(width: 36, height: 20)
            .overlay(alignment: on ? .trailing : .leading) {
                Circle().fill(.white).frame(width: 16, height: 16)
                    .shadow(color: .black.opacity(0.3), radius: 1, y: 1)
                    .padding(2)
            }
            .animation(.easeOut(duration: 0.15), value: on)
    }
}
