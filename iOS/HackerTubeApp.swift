import SwiftUI
import UIKit

@main
struct HackerTubeApp: App {
    @State private var lib = Library.shared
    @State private var router = Router()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(lib)
                .environment(router)
                .preferredColorScheme(lib.colorScheme)
                .tint(HT.good)
        }
    }
}

// MARK: - Routing (mirrors the site's paths)

enum Route: Hashable {
    case home                         // /
    case browse(Filters)              // /browse?…  (Longs is /browse?dur=xlong)
    case area(String)                 // /a/<id>
    case category(String)             // /c/<id>
    case categories                   // /categories
    case playlists                    // /playlists
    case playlist(String)             // /p/<slug>
    case watch(String)                // /watch/<vid>
    case search(String, Filters)      // /search/<q>
    case liked, history, later        // /liked /history /later
    case about, settings, data        // /about /settings /data
}

@MainActor @Observable
final class Router {
    var root: Route = .home
    var path: [Route] = []
    var drawerOpen = false
    /// The Filters panel stays open or closed across pages, as on the site.
    var filtersOpen = false
    var query = ""
    var toast: String?
    private var toastTask: Task<Void, Never>?

    var canGoBack: Bool { !path.isEmpty }
    var current: Route { path.last ?? root }

    func push(_ r: Route) {
        drawerOpen = false
        if r != current { path.append(r) }
    }

    func setRoot(_ r: Route) {
        root = r
        path = []
        drawerOpen = false
    }

    func back() { if !path.isEmpty { path.removeLast() } }

    func showToast(_ message: String) {
        toast = message
        toastTask?.cancel()
        toastTask = Task {
            try? await Task.sleep(for: .seconds(1.8))
            if !Task.isCancelled { toast = nil }
        }
    }
}

// MARK: - Layout environment

private struct NarrowKey: EnvironmentKey { static let defaultValue = false }
private struct ContentWidthKey: EnvironmentKey { static let defaultValue: CGFloat = 390 }
extension EnvironmentValues {
    /// The site's `max-width: 800px` layout: drawer sidebar, single-column grid, edge-to-edge player.
    var narrow: Bool {
        get { self[NarrowKey.self] }
        set { self[NarrowKey.self] = newValue }
    }
    var contentWidth: CGFloat {
        get { self[ContentWidthKey.self] }
        set { self[ContentWidthKey.self] = newValue }
    }
}

// MARK: - Root

struct RootView: View {
    @Environment(Router.self) private var router
    @AppStorage("collapsed") private var collapsed = false

    var body: some View {
        GeometryReader { geo in
            let narrow = geo.size.width <= 800
            let sideWidth: CGFloat = narrow ? 0 : (collapsed ? 72 : 240)
            VStack(spacing: 0) {
                TopBar(narrow: narrow) {
                    if narrow { router.drawerOpen.toggle() } else { collapsed.toggle() }
                }
                ZStack(alignment: .topLeading) {
                    HStack(spacing: 0) {
                        if !narrow {
                            Sidebar(collapsed: collapsed).frame(width: sideWidth)
                        }
                        MainStack()
                            .environment(\.narrow, narrow)
                            .environment(\.contentWidth, geo.size.width - sideWidth)
                    }
                    if narrow { Drawer() }
                }
            }
            .background(HT.bg.ignoresSafeArea())
            .overlay(alignment: .bottomLeading) { ToastView() }
        }
        .foregroundStyle(HT.text)
        .onAppear(perform: openLaunchRoute)
    }

    /// `-route <site path>` (e.g. `watch/5MgBikgcWnY`, `categories`) opens a page directly; used for testing.
    private func openLaunchRoute() {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-route"), i + 1 < args.count else { return }
        let parts = args[i + 1].split(separator: "/", maxSplits: 1).map(String.init)
        let arg = parts.count > 1 ? parts[1] : ""
        let route: Route? = switch parts.first ?? "" {
        case "watch": .watch(arg)
        case "search": .search(arg, Filters())
        case "c": .category(arg)
        case "a": .area(arg)
        case "p": .playlist(arg)
        case "categories": .categories
        case "playlists": .playlists
        case "longs": .browse(.longs)
        case "about": .about
        case "data": .data
        case "settings": .settings
        case "filters": .browse(Filters(["sort": "recent"]))
        default: nil
        }
        if let route { router.push(route) }
        if args.contains("-filtersOpen") { router.filtersOpen = true }
    }
}

/// The page stack. The browser's back button becomes the back arrow / edge swipe.
struct MainStack: View {
    @Environment(Router.self) private var router
    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.path) {
            RouteView(route: router.root)
                .id(router.root)
                .navigationDestination(for: Route.self) { RouteView(route: $0) }
        }
    }
}

struct RouteView: View {
    let route: Route
    @Environment(Router.self) private var router

    var body: some View {
        page
            .toolbar(.hidden, for: .navigationBar)
            .background(HT.bg)
            .onAppear {
                // the search box shows the query on search pages only
                if case .search(let q, _) = route { router.query = q } else { router.query = "" }
            }
    }

    @ViewBuilder private var page: some View {
        switch route {
        case .home: HomePage()
        case .browse(let f): BrowsePage(initial: f)
        case .area(let id): AreaPage(id: id)
        case .category(let id): CategoryPage(id: id)
        case .categories: CategoriesPage()
        case .playlists: PlaylistsPage()
        case .playlist(let slug): PlaylistPage(slug: slug)
        case .watch(let vid): WatchPage(vid: vid)
        case .search(let q, let f): SearchPage(query: q, initial: f)
        case .liked: SavedPage(kind: .liked)
        case .history: SavedPage(kind: .history)
        case .later: SavedPage(kind: .later)
        case .about: AboutPage()
        case .settings: SettingsPage()
        case .data: DataPage()
        }
    }
}

// Keep the edge-swipe back gesture with the navigation bar hidden.
extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }
    public func gestureRecognizerShouldBegin(_ g: UIGestureRecognizer) -> Bool { viewControllers.count > 1 }
}

// MARK: - Top bar

struct TopBar: View {
    let narrow: Bool
    let onMenu: () -> Void
    @Environment(Router.self) private var router
    @Environment(Library.self) private var lib
    @Environment(\.colorScheme) private var scheme
    @FocusState private var searchFocused: Bool

    var body: some View {
        @Bindable var router = router
        HStack(spacing: narrow ? 8 : 16) {
            HStack(spacing: narrow ? 4 : 12) {
                if narrow && router.canGoBack {
                    CircleIcon(.back, size: narrow ? 34 : 40, label: "Back") { router.back() }
                } else {
                    CircleIcon(.menu, size: narrow ? 34 : 40, label: "Menu", action: onMenu)
                }
                Button { router.setRoot(.home) } label: { Wordmark(size: narrow ? 17 : 20) }
                    .buttonStyle(.plain)
                    .accessibilityLabel("HackerTube home")
            }
            if !narrow { Spacer(minLength: 0) }
            HStack(spacing: 0) {
                TextField("Search", text: $router.query)
                    .font(.system(size: 16))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .focused($searchFocused)
                    .onSubmit(submit)
                    .padding(.horizontal, narrow ? 12 : 16)
                    .frame(height: 40)
                    .background(HT.bg)
                    .overlay(UnevenRoundedRectangle(topLeadingRadius: 20, bottomLeadingRadius: 20)
                        .stroke(searchFocused ? HT.good : HT.bg3, lineWidth: 1))
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: 20, bottomLeadingRadius: 20))
                Button(action: submit) {
                    IconView(.search).frame(width: narrow ? 44 : 64, height: 40)
                        .background(HT.bg2)
                        .overlay(UnevenRoundedRectangle(bottomTrailingRadius: 20, topTrailingRadius: 20)
                            .stroke(HT.bg3, lineWidth: 1))
                        .clipShape(UnevenRoundedRectangle(bottomTrailingRadius: 20, topTrailingRadius: 20))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Search")
            }
            .frame(maxWidth: 640)
            if !narrow { Spacer(minLength: 0) }
            HStack(spacing: 0) {
                CircleIcon(.about, size: narrow ? 34 : 40, label: "About HackerTube") { router.push(.about) }
                CircleIcon(.theme, size: narrow ? 34 : 40, label: "Toggle theme") { lib.toggleTheme(system: scheme) }
            }
        }
        .padding(.leading, narrow ? 4 : 16)
        .padding(.trailing, narrow ? 8 : 16)
        .frame(height: 56)
        .background(HT.bg)
    }

    private func submit() {
        let q = router.query.trimmingCharacters(in: .whitespaces)
        searchFocused = false
        if q.isEmpty { router.setRoot(.home) } else { router.push(.search(q, Filters())) }
    }
}

struct CircleIcon: View {
    let icon: Icon
    var size: CGFloat = 40
    var label: String
    var action: () -> Void
    init(_ icon: Icon, size: CGFloat = 40, label: String, action: @escaping () -> Void) {
        self.icon = icon
        self.size = size
        self.label = label
        self.action = action
    }
    var body: some View {
        Button(action: action) {
            IconView(icon).frame(width: size, height: 40).contentShape(Circle())
        }
        .buttonStyle(HoverCircleStyle())
        .accessibilityLabel(label)
    }
}

struct HoverCircleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.background(Circle().fill(configuration.isPressed ? HT.bg3 : .clear))
    }
}

// MARK: - Sidebar

struct NavItem: Identifiable {
    let route: Route
    let icon: Icon
    let title: String
    var id: String { title }
}

let navItems: [NavItem] = [
    NavItem(route: .home, icon: .home, title: "Home"),
    NavItem(route: .browse(.longs), icon: .longs, title: "Longs"),
    NavItem(route: .liked, icon: .liked, title: "Liked"),
    NavItem(route: .history, icon: .history, title: "History"),
    NavItem(route: .later, icon: .clock, title: "Watch later"),
    NavItem(route: .categories, icon: .categories, title: "Categories"),
    NavItem(route: .playlists, icon: .playlists, title: "Playlists"),
    NavItem(route: .settings, icon: .settings, title: "Settings"),
]

struct Sidebar: View {
    var collapsed = false
    @Environment(Router.self) private var router

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(navItems) { item in
                    // like the site, an item is "on" only when its page is the one showing
                    let on = !router.canGoBack && router.root == item.route
                    Button { router.setRoot(item.route) } label: {
                        Group {
                            if collapsed {
                                VStack(spacing: 4) {
                                    IconView(item.icon)
                                    Text(item.title).font(.system(size: 10))
                                }
                                .frame(maxWidth: .infinity).frame(height: 74)
                            } else {
                                HStack(spacing: 24) {
                                    IconView(item.icon)
                                    Text(item.title).font(.system(size: 14, weight: on ? .medium : .regular))
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 12).frame(height: 40)
                            }
                        }
                        .background(RoundedRectangle(cornerRadius: 10).fill(on ? HT.bg2 : .clear))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(collapsed ? 4 : 12)
        }
        .scrollIndicators(.hidden)
        .background(HT.bg)
    }
}

/// The narrow layout's slide-in sidebar with a scrim.
struct Drawer: View {
    @Environment(Router.self) private var router
    var body: some View {
        ZStack(alignment: .leading) {
            if router.drawerOpen {
                Color.black.opacity(0.4)
                    .ignoresSafeArea(edges: .bottom)
                    .onTapGesture { router.drawerOpen = false }
                    .transition(.opacity)
                Sidebar()
                    .frame(width: 240)
                    .shadow(color: .black.opacity(0.3), radius: 12)
                    .ignoresSafeArea(edges: .bottom)
                    .transition(.move(edge: .leading))
            }
        }
        .animation(.easeOut(duration: 0.2), value: router.drawerOpen)
    }
}

struct ToastView: View {
    @Environment(Router.self) private var router
    var body: some View {
        Group {
            if let t = router.toast {
                Text(t)
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color(hex: 0x222222)))
                    .padding(24)
                    .transition(.opacity.combined(with: .offset(y: 8)))
            }
        }
        .animation(.easeOut(duration: 0.15), value: router.toast)
        .allowsHitTesting(false)
    }
}
