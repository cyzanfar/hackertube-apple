import SwiftUI

@main
struct HackerTubeTVApp: App {
    @State private var lib = Library.shared
    @State private var router = TVRouter()

    var body: some Scene {
        WindowGroup {
            TVRoot()
                .environment(lib)
                .environment(router)
                .preferredColorScheme(lib.colorScheme ?? .dark)
        }
    }
}

// MARK: - Routing

enum TVTab: String, CaseIterable, Identifiable {
    case search, home, longs, liked, history, later, categories, playlists, settings
    var id: String { rawValue }
    var title: String {
        switch self {
        case .search: "Search"; case .home: "Home"; case .longs: "Longs"; case .liked: "Liked"
        case .history: "History"; case .later: "Watch later"; case .categories: "Categories"
        case .playlists: "Playlists"; case .settings: "Settings"
        }
    }
    var icon: Icon {
        switch self {
        case .search: .search; case .home: .home; case .longs: .longs; case .liked: .liked
        case .history: .history; case .later: .clock; case .categories: .categories
        case .playlists: .playlists; case .settings: .settings
        }
    }
}

enum TVRoute: Hashable {
    case video(String)
    case area(String)
    case category(String)
    case list(String, Filters)        // a titled /browse
    case playlist(String)
}

@MainActor @Observable
final class TVRouter {
    var tab: TVTab = .home
    var path: [TVRoute] = []
    /// The video to offer as a QR code when the YouTube app isn't there.
    var qrVideo: String?

    func push(_ r: TVRoute) { path.append(r) }
    func select(_ t: TVTab) { tab = t; path = [] }

    /// The video playing full screen inside the app.
    var playing: Video?

    /// Plays inside the app with YouTube's own player (the default), or in the YouTube app when chosen in Settings.
    func play(_ video: Video) {
        Library.shared.markSeen(video.vid)
        if Library.shared.playInApp && YouTubeWebPlayerView.isAvailable { playing = video } else { openInYouTubeApp(video.vid) }
    }

    /// Hands the video to the YouTube app (Menu there comes back here); without it, a QR code for the phone.
    func openInYouTubeApp(_ vid: String) {
        Task {
            for link in ["youtube://watch/\(vid)", "youtube://www.youtube.com/watch?v=\(vid)"] {
                if let url = URL(string: link), await UIApplication.shared.open(url) { return }
            }
            qrVideo = vid
        }
    }
}

// MARK: - Root: icon rail + page stack

struct TVRoot: View {
    @Environment(TVRouter.self) private var router
    @FocusState private var sideFocus: TVTab?
    /// Off for a moment at launch so first focus lands on the page, not the sidebar.
    @State private var sidebarReady = false
    static let rail: CGFloat = 132

    var body: some View {
        @Bindable var router = router
        ZStack(alignment: .leading) {
            NavigationStack(path: $router.path) {
                TVTabView(tab: router.tab)
                    .id(router.tab)
                    .navigationDestination(for: TVRoute.self) { TVRouteView(route: $0) }
            }
            .padding(.leading, Self.rail)
            .focusSection()
            // at the top of a tab, Menu goes to the sidebar first (then leaves the app)
            .onExitCommand(perform: router.path.isEmpty && sideFocus == nil ? { sideFocus = router.tab } : nil)

            if sideFocus != nil {
                LinearGradient(colors: [HT.bg.opacity(0.95), HT.bg.opacity(0.6)], startPoint: .leading, endPoint: .trailing)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
            TVSidebar(focus: $sideFocus)
                .disabled(!sidebarReady)
        }
        .background(HT.bg.ignoresSafeArea())
        .foregroundStyle(HT.text)
        .animation(.easeOut(duration: 0.2), value: sideFocus != nil)
        .sheet(item: Binding(get: { router.qrVideo.map(QRItem.init) }, set: { router.qrVideo = $0?.id })) { item in
            TVQRSheet(vid: item.id)
        }
        .fullScreenCover(item: $router.playing) { TVPlayerScreen(video: $0) }
        .onAppear(perform: openLaunchRoute)
    }

    /// `-tab <tab>` / `-video <id>` / `-play <id>`: open a page directly; used for testing.
    private func openLaunchRoute() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { sidebarReady = true }
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-tab"), i + 1 < args.count, let t = TVTab(rawValue: args[i + 1]) { router.select(t) }
        if let i = args.firstIndex(of: "-video"), i + 1 < args.count { router.push(.video(args[i + 1])) }
        if let i = args.firstIndex(of: "-playlist"), i + 1 < args.count { router.push(.playlist(args[i + 1])) }
        if let i = args.firstIndex(of: "-play"), i + 1 < args.count {
            let vid = args[i + 1]
            Task { if let v = try? await API.video(vid).video { router.play(v) } }
        }
        if args.contains("-sidebar") { DispatchQueue.main.asyncAfter(deadline: .now() + 1) { sideFocus = router.tab } }
    }
}

private struct QRItem: Identifiable { let id: String }

struct TVSidebar: View {
    var focus: FocusState<TVTab?>.Binding
    @Environment(TVRouter.self) private var router

    var body: some View {
        let expanded = focus.wrappedValue != nil
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 22) {
                LogoMark(size: 64)
                if expanded { Wordmark(size: 40) }
            }
            .padding(.leading, 34).padding(.bottom, 24)
            ForEach(TVTab.allCases) { tab in
                Button { router.select(tab) } label: {
                    HStack(spacing: 30) {
                        IconView(tab.icon, size: 36)
                        if expanded { Text(tab.title).font(.system(size: 30, weight: .medium)).lineLimit(1) }
                    }
                }
                .buttonStyle(TVSideItemStyle(selected: router.tab == tab, expanded: expanded))
                .focused(focus, equals: tab)
            }
            Spacer()
        }
        .padding(.top, 40)
        .frame(width: expanded ? 420 : TVRoot.rail, alignment: .leading)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(HT.bg.opacity(expanded ? 1 : 0).ignoresSafeArea())
        .focusSection()
    }
}

/// Sidebar item: focused is the inverted pill, the current tab a bg2 pill.
struct TVSideItemStyle: ButtonStyle {
    let selected: Bool
    let expanded: Bool
    func makeBody(configuration: Configuration) -> some View { StyledBody(configuration: configuration, selected: selected, expanded: expanded) }
    private struct StyledBody: View {
        let configuration: Configuration
        let selected: Bool
        let expanded: Bool
        @Environment(\.isFocused) private var focused
        var body: some View {
            configuration.label
                .foregroundStyle(focused ? HT.chipOnText : HT.text)
                .padding(.horizontal, 30)
                .frame(width: expanded ? 380 : 96, height: 80, alignment: .leading)
                .background(Capsule().fill(focused ? HT.chipOn : selected ? HT.bg2 : .clear))
                .padding(.leading, 18)
                .scaleEffect(configuration.isPressed ? 0.97 : 1)
        }
    }
}

struct TVTabView: View {
    let tab: TVTab
    var body: some View {
        switch tab {
        case .search: TVSearchPage()
        case .home: TVHomePage()
        case .longs: TVListPage(title: "Longs", sub: "Every video over an hour. The opposite of Shorts.", filters: .longs)
        case .liked: TVSavedPage(kind: .liked)
        case .history: TVSavedPage(kind: .history)
        case .later: TVSavedPage(kind: .later)
        case .categories: TVCategoriesPage()
        case .playlists: TVPlaylistsPage()
        case .settings: TVSettingsPage()
        }
    }
}

struct TVRouteView: View {
    let route: TVRoute
    var body: some View {
        switch route {
        case .video(let vid): TVVideoPage(vid: vid)
        case .area(let id): TVAreaPage(id: id)
        case .category(let id): TVCategoryPage(id: id)
        case .list(let title, let f): TVListPage(title: title, filters: f)
        case .playlist(let slug): TVPlaylistPage(slug: slug)
        }
    }
}
