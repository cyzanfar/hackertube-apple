import SwiftUI
import CoreImage.CIFilterBuiltins

// MARK: - Focus styles

private struct TVFocusedKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    /// Whether the enclosing card button has focus (drives the thumbnail ring).
    var tvFocused: Bool {
        get { self[TVFocusedKey.self] }
        set { self[TVFocusedKey.self] = newValue }
    }
}

/// Cards: no system lift; the thumbnail gets a white ring and the card grows a little.
struct TVCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { StyledBody(configuration: configuration) }
    private struct StyledBody: View {
        let configuration: Configuration
        @Environment(\.isFocused) private var focused
        var body: some View {
            configuration.label
                .environment(\.tvFocused, focused)
                .scaleEffect(configuration.isPressed ? 1.0 : focused ? 1.04 : 1)
                .animation(.easeOut(duration: 0.15), value: focused)
        }
    }
}

/// Pills and chips: bg2, inverted when focused (as in the Android TV app).
struct TVPillStyle: ButtonStyle {
    var on = false
    var radius: CGFloat? = nil
    func makeBody(configuration: Configuration) -> some View { StyledBody(configuration: configuration, on: on, radius: radius) }
    private struct StyledBody: View {
        let configuration: Configuration
        let on: Bool
        let radius: CGFloat?
        @Environment(\.isFocused) private var focused
        var body: some View {
            let inverted = focused || on
            configuration.label
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(inverted ? HT.chipOnText : HT.text)
                .padding(.horizontal, 28).frame(minHeight: 64)
                .background(RoundedRectangle(cornerRadius: radius ?? 32, style: .continuous)
                    .fill(focused ? HT.chipOn : on ? HT.chipOn.opacity(0.85) : HT.bg2))
                .scaleEffect(focused ? (configuration.isPressed ? 1.0 : 1.06) : 1)
                .shadow(color: .black.opacity(focused ? 0.35 : 0), radius: 12, y: 6)
                .animation(.easeOut(duration: 0.15), value: focused)
        }
    }
}

struct TVPill: View {
    var icon: Icon? = nil
    let title: String
    var on = false
    var radius: CGFloat? = nil
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                if let icon { IconView(icon, size: 32) }
                Text(title).lineLimit(1)
            }
        }
        .buttonStyle(TVPillStyle(on: on, radius: radius))
    }
}

// MARK: - Cards

struct TVThumb: View {
    let video: Video
    var showDuration = true
    @Environment(\.tvFocused) private var focused
    @Environment(Library.self) private var lib

    var body: some View {
        VideoImage(vid: video.vid)
            .aspectRatio(16 / 9, contentMode: .fit)
            .overlay(alignment: .bottomTrailing) {
                let d = formatDuration(video.durationS)
                if showDuration && !d.isEmpty {
                    Text(d).font(.system(size: 22, weight: .medium)).foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 6).fill(HT.badge))
                        .padding(12)
                }
            }
            .overlay(alignment: .topTrailing) {
                if lib.isLater(video.vid) {
                    IconView(.check, size: 28).foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(RoundedRectangle(cornerRadius: 6).fill(HT.badge))
                        .padding(10)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.white, lineWidth: 5)
                    .padding(-6)
                    .opacity(focused ? 1 : 0)
            }
    }
}

/// Video card: select opens the video's page; long-press (hold Select) for Play / Watch later / Like.
struct TVCard: View {
    let video: Video
    @Environment(TVRouter.self) private var router
    @Environment(Library.self) private var lib

    var body: some View {
        Button { router.push(.video(video.vid)) } label: {
            VStack(alignment: .leading, spacing: 0) {
                TVThumb(video: video)
                Text(video.title).font(.system(size: 26, weight: .medium)).lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(.top, 18).padding(.bottom, 4)
                Text(video.channel ?? "").font(.system(size: 22)).foregroundStyle(HT.muted).lineLimit(1)
                Text(video.stats).font(.system(size: 22)).foregroundStyle(HT.muted).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .buttonStyle(TVCardStyle())
        .contextMenu {
            if let r = video.reason, !r.isEmpty { Text(r) }
            Button("Play") { router.play(video) }
            Button("Open in YouTube app") { router.openInYouTubeApp(video.vid) }
            Button(lib.isLater(video.vid) ? "Remove from Watch later" : "Watch later") { lib.toggleLater(video.vid) }
            Button(lib.isLiked(video.vid) ? "Remove from Liked" : "Like") { lib.toggleLike(video.vid) }
        }
    }
}

struct TVGrid: View {
    let videos: [Video]
    var onAppear: ((Video) -> Void)? = nil
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 48, alignment: .top), count: 4),
                  alignment: .leading, spacing: 64) {
            ForEach(videos) { v in TVCard(video: v).onAppear { onAppear?(v) } }
        }
    }
}

struct TVPagedGrid: View {
    let pager: Pager
    var filtering = false
    var body: some View {
        if pager.items.isEmpty && pager.done {
            TVStatus(text: pager.error ?? (filtering ? "No videos match these filters." : "Nothing here yet."))
        } else if pager.items.isEmpty {
            TVStatus(text: "Loading…")
        } else {
            TVGrid(videos: pager.items) { pager.appeared($0) }
            if pager.loading { ProgressView().frame(maxWidth: .infinity).padding(.vertical, 40) }
        }
    }
}

// MARK: - Page scaffolding

struct TVPage<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) { content }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 64)
                .padding(.top, 24)
                .padding(.bottom, 80)
        }
        .scrollClipDisabled()
    }
}

struct TVHead: View {
    var crumb: String? = nil
    let title: String
    var sub: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let crumb { Text(crumb).font(.system(size: 24)).foregroundStyle(HT.muted) }
            Text(title).font(.system(size: 48, weight: .bold))
            if let sub { Text(sub).font(.system(size: 26)).foregroundStyle(HT.muted) }
        }
        .padding(.bottom, 36)
    }
}

struct TVStatus: View {
    let text: String
    var body: some View {
        Text(text).font(.system(size: 28)).foregroundStyle(HT.muted)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity).padding(.vertical, 80)
    }
}

/// `.mosaic`: four frames in a 2×2 grid.
struct TVMosaic: View {
    let vids: [String]
    var badge: String? = nil
    @Environment(\.tvFocused) private var focused
    var body: some View {
        let c = Array(vids.prefix(4))
        Grid(horizontalSpacing: 3, verticalSpacing: 3) {
            GridRow { cell(c, 0); cell(c, 1) }
            GridRow { cell(c, 2); cell(c, 3) }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .background(HT.bg2)
        .overlay(alignment: .bottomTrailing) {
            if let badge {
                Text(badge).font(.system(size: 22, weight: .medium)).foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(HT.badge))
                    .padding(12)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(.white, lineWidth: 5)
                .padding(-6).opacity(focused ? 1 : 0)
        }
    }
    @ViewBuilder private func cell(_ c: [String], _ i: Int) -> some View {
        if i < c.count { VideoImage(vid: c[i]) } else { HT.bg2 }
    }
}

// MARK: - QR fallback

/// Shown when a video can only play on YouTube itself and no YouTube app is installed: watch on your phone instead.
struct TVQRSheet: View {
    let vid: String
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        let link = "https://hackertube.org/watch/\(vid)"
        HStack(spacing: 80) {
            qr(link).interpolation(.none).resizable().frame(width: 420, height: 420)
                .padding(24).background(RoundedRectangle(cornerRadius: 24).fill(.white))
            VStack(alignment: .leading, spacing: 24) {
                Text("This video plays only on YouTube").font(.system(size: 48, weight: .bold))
                Text("The uploader doesn't allow this video to play in other apps. Install the YouTube app from the App Store, or scan the code to watch it on your phone.")
                    .font(.system(size: 30)).foregroundStyle(HT.muted)
                Text(link).font(.system(size: 26, design: .monospaced)).foregroundStyle(HT.muted)
                TVPill(title: "OK") { dismiss() }.padding(.top, 20)
            }
            .frame(maxWidth: 900, alignment: .leading)
        }
        .padding(80)
    }

    private func qr(_ s: String) -> Image {
        let f = CIFilter.qrCodeGenerator()
        f.message = Data(s.utf8)
        f.correctionLevel = "M"
        if let out = f.outputImage, let cg = CIContext().createCGImage(out, from: out.extent) {
            return Image(decorative: cg, scale: 1)
        }
        return Image(systemName: "qrcode")
    }
}
