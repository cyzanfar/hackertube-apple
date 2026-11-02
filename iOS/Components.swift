import SwiftUI

// MARK: - Page scaffolding

/// `main`: 24px side padding (16 when narrow), 40px bottom (32).
struct PageScroll<Content: View>: View {
    @Environment(\.narrow) private var narrow
    var maxWidth: CGFloat? = nil
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) { content }
                .frame(maxWidth: maxWidth, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: maxWidth == nil ? .leading : .center)
                .padding(.horizontal, narrow ? 16 : 24)
                .padding(.bottom, narrow ? 32 : 40)
        }
        .scrollDismissesKeyboard(.immediately)
    }
}

/// `.pagehead`: an optional breadcrumb, a 24px title and an optional subtitle.
struct PageHead: View {
    var crumb: String? = nil
    var onCrumb: (() -> Void)? = nil
    let title: String
    var sub: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let crumb {
                Button { onCrumb?() } label: { Text(crumb).font(.system(size: 14)).foregroundStyle(HT.muted) }
                    .buttonStyle(.plain)
                    .padding(.top, 16)
            }
            Text(title).font(.system(size: 24, weight: .bold)).padding(.top, crumb == nil ? 16 : 2)
            if let sub { Text(sub).font(.system(size: 14)).foregroundStyle(HT.muted).padding(.top, 4) }
        }
    }
}

struct StatusText: View {
    let text: String
    var body: some View {
        Text(text).font(.system(size: 14)).foregroundStyle(HT.muted)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity).padding(.vertical, 24)
    }
}

/// Body text with the site's line heights.
extension Text {
    func ht(_ size: CGFloat, _ weight: Font.Weight = .regular, line: CGFloat? = nil) -> some View {
        let lh = line ?? size * 1.4
        return self.font(.system(size: size, weight: weight)).lineSpacing(max(0, lh - size * 1.19))
    }
}

// MARK: - Pills and chips

/// `.pill`: 36px tall, fully rounded, bg2.
struct Pill: View {
    var icon: Icon? = nil
    let title: String
    var on = false
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon { IconView(icon, size: 20) }
                Text(title).font(.system(size: 14, weight: .medium)).lineLimit(1)
            }
            .padding(.horizontal, 16).frame(height: 36)
            .background(Capsule().fill(on ? HT.bg3 : HT.bg2))
            .contentShape(Capsule())
        }
        .buttonStyle(PressStyle())
    }
}

/// `.chip`: 32px tall, radius 8; `.on` is inverted.
struct Chip: View {
    let title: String
    var on = false
    var trailingX = false
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title).font(.system(size: 14, weight: .medium)).lineLimit(1)
                if trailingX { Text("×").font(.system(size: 16)).opacity(0.7) }
            }
            .foregroundStyle(on ? HT.chipOnText : HT.text)
            .padding(.horizontal, 12).frame(height: 32)
            .background(RoundedRectangle(cornerRadius: 8).fill(on ? HT.chipOn : HT.chip))
        }
        .buttonStyle(PressStyle())
    }
}

struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// "Play all on YouTube": the videos on the page as a temporary YouTube playlist.
struct PlayAllPill: View {
    let vids: [String]
    @Environment(\.openURL) private var openURL
    var body: some View {
        Pill(icon: .playAll, title: "Play all on YouTube") {
            if let url = playAllURL(vids) { openURL(url) }
        }
    }
}

// MARK: - Thumbnails and cards

struct Thumb: View {
    let video: Video
    var radius: CGFloat = 12
    var showLaterBadge = true
    @Environment(Library.self) private var lib

    var body: some View {
        VideoImage(vid: video.vid)
            .aspectRatio(16 / 9, contentMode: .fit)
            .overlay(alignment: .bottomTrailing) {
                let d = formatDuration(video.durationS)
                if !d.isEmpty {
                    Text(d).font(.system(size: 12, weight: .medium)).foregroundStyle(.white)
                        .padding(.horizontal, 4).padding(.vertical, 1)
                        .background(RoundedRectangle(cornerRadius: 4).fill(HT.badge))
                        .padding(8)
                }
            }
            .overlay(alignment: .topTrailing) {
                // touch has no hover: the clock badge shows once a video is saved
                if showLaterBadge && lib.isLater(video.vid) {
                    Button { lib.toggleLater(video.vid) } label: {
                        IconView(.check, size: 20).foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(RoundedRectangle(cornerRadius: 4).fill(HT.badge))
                    }
                    .buttonStyle(.plain)
                    .padding(6)
                    .accessibilityLabel("Remove from Watch later")
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

/// Long-press actions: the site's hover tooltip (why Home picked it), Watch later and Like.
struct VideoMenu: ViewModifier {
    let video: Video
    @Environment(Library.self) private var lib
    @Environment(Router.self) private var router
    @Environment(\.openURL) private var openURL

    func body(content: Content) -> some View {
        content.contextMenu {
            if let r = video.reason, !r.isEmpty { Section(r) {} }
            Button {
                router.showToast(lib.toggleLater(video.vid) ? "Saved to Watch later" : "Removed from Watch later")
            } label: {
                Label(lib.isLater(video.vid) ? "Remove from Watch later" : "Watch later", systemImage: lib.isLater(video.vid) ? "checkmark" : "clock")
            }
            Button {
                lib.toggleLike(video.vid)
                router.showToast(lib.isLiked(video.vid) ? "Added to Liked" : "Removed from Liked")
            } label: {
                Label(lib.isLiked(video.vid) ? "Remove from Liked" : "Like", systemImage: lib.isLiked(video.vid) ? "hand.thumbsup.fill" : "hand.thumbsup")
            }
            Button { openURL(youtubeURL(video.vid)) } label: { Label("Open in YouTube", systemImage: "arrow.up.right.square") }
            ShareLink(item: URL(string: "https://hackertube.org/watch/\(video.vid)")!) { Label("Share", systemImage: "square.and.arrow.up") }
        }
    }
}

extension View {
    func videoMenu(_ v: Video) -> some View { modifier(VideoMenu(video: v)) }
}

/// `.vcard`: the grid card.
struct VideoCard: View {
    let video: Video
    @Environment(Router.self) private var router
    var body: some View {
        Button { router.push(.watch(video.vid)) } label: {
            VStack(alignment: .leading, spacing: 0) {
                Thumb(video: video)
                VStack(alignment: .leading, spacing: 0) {
                    Text(video.title).ht(16, .medium, line: 22).lineLimit(2)
                        .multilineTextAlignment(.leading).padding(.bottom, 4)
                    Text(video.channel ?? "").ht(14, line: 20).foregroundStyle(HT.muted).lineLimit(1)
                    Text(video.stats).ht(14, line: 20).foregroundStyle(HT.muted).lineLimit(1)
                }
                .padding(.top, 12)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .videoMenu(video)
    }
}

/// `.srow`: the search-results row (stacks when narrow).
struct SearchRow: View {
    let video: Video
    @Environment(Router.self) private var router
    @Environment(\.narrow) private var narrow

    var body: some View {
        Button { router.push(.watch(video.vid)) } label: {
            let info = VStack(alignment: .leading, spacing: 0) {
                Text(video.title).ht(18, line: 26).lineLimit(2).multilineTextAlignment(.leading).padding(.bottom, 4)
                Text(video.stats).ht(14, line: 20).foregroundStyle(HT.muted)
                Text(video.channel ?? "").font(.system(size: 14)).foregroundStyle(HT.muted).padding(.vertical, 12)
                Text(video.summary ?? "").ht(12, line: 18).foregroundStyle(HT.muted).lineLimit(2)
                    .multilineTextAlignment(.leading)
                if let via = video.via, !via.isEmpty {
                    Text("Topic match · \(via)").font(.system(size: 12)).foregroundStyle(HT.muted)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 4).fill(HT.bg2))
                        .padding(.top, 8)
                }
            }
            Group {
                if narrow {
                    VStack(alignment: .leading, spacing: 8) { Thumb(video: video); info }
                } else {
                    HStack(alignment: .top, spacing: 16) { Thumb(video: video).frame(width: 360); info }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .videoMenu(video)
    }
}

/// `.next`: the compact "up next" row on the watch page.
struct NextRow: View {
    let video: Video
    @Environment(Router.self) private var router
    var body: some View {
        Button { router.push(.watch(video.vid)) } label: {
            HStack(alignment: .top, spacing: 8) {
                Thumb(video: video, radius: 8, showLaterBadge: false).frame(width: 168)
                VStack(alignment: .leading, spacing: 0) {
                    Text(video.title).ht(14, .medium, line: 20).lineLimit(2).multilineTextAlignment(.leading)
                        .padding(.bottom, 4)
                    Text(video.channel ?? "").ht(12, line: 18).foregroundStyle(HT.muted).lineLimit(1)
                    Text(video.stats).ht(12, line: 18).foregroundStyle(HT.muted).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .videoMenu(video)
    }
}

// MARK: - Grid

struct VideoGrid: View {
    let videos: [Video]
    var onAppear: ((Video) -> Void)? = nil
    @Environment(\.narrow) private var narrow

    var body: some View {
        let columns = narrow ? [GridItem(.flexible())] : [GridItem(.adaptive(minimum: 300), spacing: 16, alignment: .top)]
        LazyVGrid(columns: columns, alignment: .leading, spacing: narrow ? 24 : 40) {
            ForEach(videos) { v in
                VideoCard(video: v).onAppear { onAppear?(v) }
            }
        }
        .padding(.top, 12)
    }
}

/// The infinite-scroll grid with the site's empty and loading states.
struct PagedGrid: View {
    let pager: Pager
    var filtering = false
    var body: some View {
        if pager.items.isEmpty && pager.done {
            StatusText(text: pager.error ?? (filtering ? "No videos match these filters." : "Nothing here yet."))
        } else {
            VideoGrid(videos: pager.items) { pager.appeared($0) }
            if pager.loading { ProgressView().frame(maxWidth: .infinity).padding(.vertical, 24) }
            else if let e = pager.error { StatusText(text: e) }
        }
    }
}

// MARK: - Filters

/// The Filters button, chips for the active filters, Play all, and the collapsible panel.
struct FilterBar: View {
    let filters: Filters
    var listing = false
    var playable = true
    var vids: [String] = []
    let onSelect: (Filters) -> Void
    @Environment(Router.self) private var router

    var body: some View {
        @Bindable var router = router
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                FlowLayout(spacing: 8) {
                    Pill(icon: .filters, title: "Filters", on: router.filtersOpen) {
                        withAnimation(.easeOut(duration: 0.15)) { router.filtersOpen.toggle() }
                    }
                    ForEach(activeFilterOptions(filters, listing: listing), id: \.self) { o in
                        Chip(title: o.label, on: true, trailingX: true) { onSelect(filters.toggling(o.key, o.value)) }
                    }
                }
                Spacer(minLength: 0)
                if playable { PlayAllPill(vids: vids) }
            }
            .padding(.top, 16)
            if router.filtersOpen {
                FlowLayout(spacing: 40, lineSpacing: 16, alignment: .top) {
                    ForEach(filterGroups(listing: listing), id: \.self) { g in
                        VStack(alignment: .leading, spacing: 0) {
                            Text(g.title.uppercased()).font(.system(size: 12, weight: .medium)).tracking(0.5)
                                .foregroundStyle(HT.muted)
                                .padding(.bottom, 10)
                                .frame(minWidth: 140, alignment: .leading)
                                .overlay(alignment: .bottom) { Rectangle().fill(HT.bg3).frame(height: 1) }
                                .padding(.bottom, 8)
                            ForEach(g.options, id: \.self) { o in
                                let on = filters[o.key] == o.value
                                Button {
                                    router.filtersOpen = false   // choosing an option closes the panel, as on YouTube
                                    onSelect(filters.toggling(o.key, o.value))
                                } label: {
                                    Text(o.label).font(.system(size: 14, weight: on ? .medium : .regular))
                                        .foregroundStyle(on ? HT.text : HT.muted)
                                        .padding(.vertical, 7)
                                        .frame(minWidth: 140, alignment: .leading)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.top, 16).padding(.bottom, 8)
                .frame(maxWidth: 1100, alignment: .leading)
                .overlay(alignment: .bottom) { Rectangle().fill(HT.bg3).frame(height: 1) }
            }
        }
        .frame(maxWidth: 1100, alignment: .leading)
    }
}

// MARK: - Playlists

/// `.mosaic`: four frames in a 2×2 grid.
struct Mosaic: View {
    let vids: [String]
    var badge: String? = nil
    var body: some View {
        let cells = Array(vids.prefix(4))
        Grid(horizontalSpacing: 2, verticalSpacing: 2) {
            GridRow {
                cell(cells, 0); cell(cells, 1)
            }
            GridRow {
                cell(cells, 2); cell(cells, 3)
            }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .background(HT.bg2)
        .overlay(alignment: .bottomTrailing) {
            if let badge {
                Text(badge).font(.system(size: 12, weight: .medium)).foregroundStyle(.white)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 4).fill(HT.badge))
                    .padding(8)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder private func cell(_ c: [String], _ i: Int) -> some View {
        if i < c.count { VideoImage(vid: c[i]) } else { HT.bg2 }
    }
}

struct PlaylistCardView: View {
    let p: PlaylistCard
    @Environment(Router.self) private var router
    var body: some View {
        Button { router.push(.playlist(p.slug)) } label: {
            VStack(alignment: .leading, spacing: 0) {
                Mosaic(vids: p.cover ?? [], badge: "\(p.count ?? 0) videos · \(formatHours(p.minutes))")
                Text(p.title).ht(16, .medium, line: 22).lineLimit(2).multilineTextAlignment(.leading)
                    .padding(.top, 10).padding(.bottom, 4)
                Text(p.pitch ?? "").ht(14, line: 20).foregroundStyle(HT.muted).multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
