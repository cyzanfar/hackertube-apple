import SwiftUI

// MARK: - Home: a chip per topic area, then the feed

struct TVHomePage: View {
    @Environment(Library.self) private var lib
    @State private var areas: [Area] = []
    @State private var area: String? = nil
    @State private var pager: Pager?

    var body: some View {
        TVPage {
            Wordmark(size: 52).padding(.bottom, 32)
            ScrollView(.horizontal) {
                HStack(spacing: 20) {
                    TVPill(title: "All", on: area == nil, radius: 14) { area = nil }
                    ForEach(areas) { a in TVPill(title: a.name, on: area == a.id, radius: 14) { area = a.id } }
                }
                .padding(.vertical, 20)
            }
            .scrollClipDisabled()
            .scrollIndicators(.hidden)
            .focusSection()
            .padding(.bottom, 28)
            if let pager { TVPagedGrid(pager: pager) }
        }
        .task { if areas.isEmpty { areas = (try? await API.areas()) ?? [] } }
        .onAppear { if pager?.key != AnyHashable(area) { reload() } }
        .onChange(of: area) { reload() }
    }

    private func reload() {
        let area = area, lib = lib
        let p = Pager(key: AnyHashable(area)) { offset in
            if let area { try await API.list([("area", area)], offset: offset) } else { try await API.feed(lib, offset: offset) }
        }
        pager = p
        p.more()
    }
}

// MARK: - Lists (/browse, /a, /c)

struct TVListPage: View {
    var crumb: String? = nil
    let title: String
    var sub: String? = nil
    var base: [(String, String)] = []
    var filters = Filters()
    @State private var pager: Pager?

    var body: some View {
        TVPage {
            TVHead(crumb: crumb, title: title, sub: sub)
            if let pager { TVPagedGrid(pager: pager, filtering: filters.filtering) }
        }
        .onAppear {
            guard pager == nil else { return }
            let params = base + filters.params
            let p = Pager(key: AnyHashable(title)) { try await API.list(params, offset: $0) }
            pager = p
            p.more()
        }
    }
}

struct TVAreaPage: View {
    let id: String
    @State private var area: Area?
    @Environment(TVRouter.self) private var router
    var body: some View {
        Group {
            if let area {
                TVListPage(title: area.name, base: [("area", id)])
            } else { TVStatus(text: "Loading…") }
        }
        .task { area = try? await API.areas().first { $0.id == id } }
    }
}

struct TVCategoryPage: View {
    let id: String
    @State private var found: (Area, Category)?
    var body: some View {
        Group {
            if let (a, c) = found { TVListPage(crumb: a.name, title: c.name, base: [("cat", id)]) }
            else { TVStatus(text: "Loading…") }
        }
        .task {
            if let areas = try? await API.areas(), let a = areas.first(where: { $0.categories.contains { $0.id == id } }),
               let c = a.categories.first(where: { $0.id == id }) { found = (a, c) }
        }
    }
}

// MARK: - Categories

struct TVCategoriesPage: View {
    @State private var areas: [Area]?
    @Environment(TVRouter.self) private var router
    var body: some View {
        TVPage {
            TVHead(title: "Categories")
            HStack(spacing: 20) {
                TVPill(title: "Recently recommended") { router.push(.list("Recently recommended", Filters(["sort": "recent"]))) }
                TVPill(title: "Longs") { router.push(.list("Longs", .longs)) }
                TVPill(title: "Hidden gems") { router.push(.list("Hidden gems", Filters(["gems": "1"]))) }
                TVPill(title: "All videos") { router.push(.list("All videos", Filters())) }
            }
            .focusSection()
            .padding(.bottom, 24)
            if let areas {
                ForEach(areas) { a in
                    VStack(alignment: .leading, spacing: 18) {
                        Button { router.push(.area(a.id)) } label: {
                            HStack(alignment: .firstTextBaseline, spacing: 16) {
                                Text(a.name).font(.system(size: 34, weight: .semibold))
                                Text("\(a.count)").font(.system(size: 24)).foregroundStyle(HT.muted)
                            }
                        }
                        .buttonStyle(TVPillStyle(radius: 14))
                        FlowLayout(spacing: 16, lineSpacing: 16) {
                            ForEach(a.categories) { c in
                                TVPill(title: "\(c.name)  \(c.count)", radius: 14) { router.push(.category(c.id)) }
                            }
                        }
                    }
                    .padding(.top, 40)
                    .focusSection()
                }
            } else { TVStatus(text: "Loading…") }
        }
        .task { if areas == nil { areas = try? await API.areas() } }
    }
}

// MARK: - Playlists

struct TVPlaylistsPage: View {
    @State private var playlists: [PlaylistCard]?
    @Environment(TVRouter.self) private var router
    var body: some View {
        TVPage {
            TVHead(title: "Playlists", sub: "Curated by Claude from what Hacker News recommends, each in a deliberate order.")
            if let playlists {
                ForEach([("start", "Start here", "Broad, essential lists for your first visit."),
                         ("deep", "Deep dives", "One obsession each, for when you want to go down a rabbit hole.")], id: \.0) { tier, title, blurb in
                    let ps = playlists.filter { ($0.tier ?? "deep") == tier }
                    if !ps.isEmpty {
                        Text(title).font(.system(size: 36, weight: .bold)).padding(.top, 24)
                        Text(blurb).font(.system(size: 24)).foregroundStyle(HT.muted).padding(.top, 4).padding(.bottom, 28)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 48, alignment: .top), count: 3), spacing: 56) {
                            ForEach(ps) { p in
                                Button { router.push(.playlist(p.slug)) } label: {
                                    VStack(alignment: .leading, spacing: 0) {
                                        TVMosaic(vids: p.cover ?? [], badge: "\(p.count ?? 0) videos · \(formatHours(p.minutes))")
                                        Text(p.title).font(.system(size: 28, weight: .medium)).lineLimit(2)
                                            .padding(.top, 18).padding(.bottom, 6)
                                        Text(p.pitch ?? "").font(.system(size: 22)).foregroundStyle(HT.muted).lineLimit(3)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .topLeading)
                                }
                                .buttonStyle(TVCardStyle())
                            }
                        }
                        .padding(.bottom, 24)
                    }
                }
            } else { TVStatus(text: "Loading…") }
        }
        .task { if playlists == nil { playlists = (try? await API.playlists()) ?? [] } }
    }
}

struct TVPlaylistPage: View {
    let slug: String
    @State private var pl: Playlist?
    @State private var failed = false
    var body: some View {
        TVPage {
            if let pl {
                HStack(alignment: .top, spacing: 56) {
                    TVMosaic(vids: pl.videos.map(\.vid)).frame(width: 640)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Playlists").font(.system(size: 24)).foregroundStyle(HT.muted)
                        Text(pl.title).font(.system(size: 48, weight: .bold)).padding(.top, 6).padding(.bottom, 10)
                        Text("Curated by Claude · \(pl.videos.count) videos · \(formatHours(pl.minutes))")
                            .font(.system(size: 24)).foregroundStyle(HT.muted)
                        Text(pl.intro ?? "").font(.system(size: 26)).lineSpacing(6).padding(.top, 20)
                    }
                }
                .padding(.bottom, 56)
                LazyVStack(alignment: .leading, spacing: 40) {
                    ForEach(Array(pl.videos.enumerated()), id: \.element.vid) { i, v in TVPlaylistRow(index: i + 1, video: v) }
                }
            } else { TVStatus(text: failed ? "Not found." : "Loading…") }
        }
        .task {
            guard pl == nil else { return }
            do { pl = try await API.playlist(slug) } catch { failed = true }
        }
    }
}

struct TVPlaylistRow: View {
    let index: Int
    let video: Video
    @Environment(TVRouter.self) private var router
    var body: some View {
        Button { router.push(.video(video.vid)) } label: {
            HStack(alignment: .top, spacing: 36) {
                Text("\(index)").font(.system(size: 28)).foregroundStyle(HT.muted).frame(width: 44, alignment: .trailing).padding(.top, 6)
                TVThumb(video: video).frame(width: 480)
                VStack(alignment: .leading, spacing: 8) {
                    Text(video.title).font(.system(size: 30, weight: .medium)).lineLimit(2)
                    Text([video.channel ?? "", video.stats].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.system(size: 22)).foregroundStyle(HT.muted)
                    Text(video.note ?? "").font(.system(size: 24)).lineSpacing(4).padding(.top, 8)
                }
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(TVCardStyle())
    }
}

// MARK: - Liked, History, Watch later

struct TVSavedPage: View {
    enum Kind { case liked, history, later }
    let kind: Kind
    @Environment(Library.self) private var lib
    @State private var videos: [Video]?
    @State private var loadedFor: [String]?

    private var vids: [String] { switch kind { case .liked: lib.likes; case .history: lib.seen; case .later: lib.later } }

    var body: some View {
        TVPage {
            let title = switch kind { case .liked: "Liked videos"; case .history: "History"; case .later: "Watch later" }
            let empty = switch kind {
            case .liked: "Videos you like will show up here, and shape your Home feed."
            case .history: "Videos you open will show up here."
            case .later: "Save videos to watch later from a video's page, or hold Select on a video."
            }
            TVHead(title: title)
            if kind == .history && !lib.seen.isEmpty {
                TVPill(title: "Clear all watch history") { lib.clearHistory() }.padding(.bottom, 40)
            }
            if let videos, !videos.isEmpty { TVGrid(videos: videos) }
            else if videos != nil { TVStatus(text: empty) }
        }
        .task(id: vids) {
            let want = Array(vids.reversed())
            if loadedFor == want { return }
            if want.isEmpty { videos = []; loadedFor = want; return }
            if let v = videos { videos = v.filter { want.contains($0.vid) } }
            if let docs = try? await API.docs(want) { videos = docs; loadedFor = want } else if videos == nil { videos = [] }
        }
    }
}

// MARK: - Search, by words or by meaning

struct TVSearchPage: View {
    @State private var query = ""
    @State private var results: SearchResults?
    @State private var message: String?

    var body: some View {
        TVPage {
            if let message { TVStatus(text: message) }
            else if let results {
                if results.weak == true {
                    Text(results.results.isEmpty ? "No videos match “\(query)”." : "No strong matches for “\(query)”. Here are the closest videos.")
                        .font(.system(size: 26)).foregroundStyle(HT.muted).padding(.bottom, 32)
                }
                TVGrid(videos: results.results)
            } else if !query.isEmpty {
                TVStatus(text: "Searching…")
            } else {
                TVStatus(text: "Search understands topics, not just keywords: try “distributed systems”.")
            }
        }
        .searchable(text: $query, prompt: "Search")
        .task(id: query) {
            let q = query.trimmingCharacters(in: .whitespaces)
            results = nil
            message = nil
            guard !q.isEmpty else { return }
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            do { results = try await API.search(q) }
            catch let e as APIError where e.code == 429 || e.code == 503 {
                message = "Lots of searches right now. Give it a minute and try again."
            } catch {
                if !Task.isCancelled { message = "Something went wrong (\(error.localizedDescription))." }
            }
        }
    }
}

// MARK: - Settings

struct TVSettingsPage: View {
    @Environment(Library.self) private var lib
    var body: some View {
        TVPage {
            TVHead(title: "Settings")
            Button { lib.frames.toggle() } label: {
                HStack(alignment: .top, spacing: 48) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Show video frames instead of thumbnails").font(.system(size: 30, weight: .medium))
                        Text("YouTube thumbnails are designed by uploaders to grab your attention: big faces, arrows, shouting text. With this on, every video is shown with a frame from the middle of the video instead, so you see what it actually looks like. Turn it off to see the original thumbnails.")
                            .font(.system(size: 24)).lineSpacing(4).opacity(0.75)
                    }
                    Spacer(minLength: 0)
                    Text(lib.frames ? "On" : "Off").font(.system(size: 28, weight: .semibold))
                }
                .padding(.vertical, 20)
                .frame(maxWidth: 1300, alignment: .leading)
            }
            .buttonStyle(TVPillStyle(radius: 20))
            .padding(.bottom, 32)

            Text("Play videos in").font(.system(size: 30, weight: .medium)).padding(.bottom, 8)
            Text("HackerTube plays videos right here with YouTube's own player, in standard quality (360p). The YouTube app plays them in HD.")
                .font(.system(size: 24)).foregroundStyle(HT.muted).padding(.bottom, 20).frame(maxWidth: 1300, alignment: .leading)
            HStack(spacing: 20) {
                TVPill(title: "HackerTube", on: lib.playInApp) { lib.playInApp = true }
                TVPill(title: "YouTube app", on: !lib.playInApp) { lib.playInApp = false }
            }
            .focusSection()
            .padding(.bottom, 56)

            Text("Appearance").font(.system(size: 30, weight: .medium)).padding(.bottom, 20)
            HStack(spacing: 20) {
                TVPill(title: "Dark", on: lib.theme == nil || lib.theme == "dark") { lib.theme = nil }
                TVPill(title: "Light", on: lib.theme == "light") { lib.theme = "light" }
            }
            .focusSection()
            .padding(.bottom, 56)

            Text("HackerTube: the YouTube videos that Hacker News keeps telling each other to watch. Your likes, history and Watch later list stay on this Apple TV. Videos and curation come from hackertube.org.")
                .font(.system(size: 24)).foregroundStyle(HT.muted).frame(maxWidth: 1300, alignment: .leading)
        }
    }
}
