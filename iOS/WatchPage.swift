import SwiftUI
import WebKit

/// /watch/<vid>
struct WatchPage: View {
    let vid: String
    @State private var page: VideoPage?
    @State private var related: [Video]?
    @State private var failed = false
    @State private var playing = ProcessInfo.processInfo.arguments.contains("-play")   // -play: testing hook
    @Environment(Library.self) private var lib
    @Environment(\.narrow) private var narrow
    @Environment(\.contentWidth) private var contentWidth

    var body: some View {
        ScrollView {
            if let page {
                let twoColumn = contentWidth > 1100
                Group {
                    if twoColumn {
                        HStack(alignment: .top, spacing: 24) {
                            primary(page)
                            upNext.frame(width: 402)
                        }
                        .frame(maxWidth: 1754)
                        .padding(.top, 24)
                    } else {
                        VStack(alignment: .leading, spacing: 0) {
                            primary(page)
                            upNext.padding(.horizontal, narrow ? 16 : 0)
                        }
                        .padding(.top, narrow ? 0 : 24)
                    }
                }
                .padding(.horizontal, narrow ? 0 : 24)
                .padding(.bottom, narrow ? 32 : 40)
                .frame(maxWidth: .infinity)
            } else {
                StatusText(text: failed ? "Not found." : "Loading…")
            }
        }
        .task {
            guard page == nil else { return }
            do {
                let p = try await API.video(vid)
                page = p
                lib.markSeen(p.video.vid)
            } catch { failed = true; return }
            related = try? await API.related(vid)
        }
    }

    // MARK: primary column

    @ViewBuilder private func primary(_ data: VideoPage) -> some View {
        let d = data.video
        let side: CGFloat = narrow ? 16 : 0
        VStack(alignment: .leading, spacing: 0) {
            player(d)
            Text(d.title).ht(20, .bold, line: 28)
                .padding(.top, 12).padding(.bottom, 8).padding(.horizontal, side)
            Owner(video: d).padding(.horizontal, side)
            Description(video: d).padding(.top, 12).padding(.horizontal, side)
            Comments(comments: data.comments).padding(.horizontal, side)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private func player(_ d: Video) -> some View {
        // with frames on, start with the frame + a play button (YouTube's embed would show the custom thumbnail)
        ZStack {
            Color.black
            if playing || !lib.frames {
                YouTubePlayer(vid: d.vid, autoplay: playing)
            } else {
                Button { playing = true } label: {
                    VideoImage(vid: d.vid)
                        .overlay {
                            IconView(.play, size: 32).foregroundStyle(.white)
                                .frame(width: 68, height: 48)
                                .background(RoundedRectangle(cornerRadius: 14).fill(Color.black.opacity(0.7)))
                        }
                }
                .buttonStyle(PosterStyle())
                .accessibilityLabel("Play \(d.title)")
            }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: narrow ? 0 : 12, style: .continuous))
    }

    @ViewBuilder private var upNext: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let related {
                ForEach(related) { NextRow(video: $0) }
            } else {
                StatusText(text: "Loading…")
            }
        }
        .padding(.top, contentWidth > 1100 ? 0 : 8)
    }
}

/// The play button turns orange while pressed (the site's hover).
private struct PosterStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.overlay {
            if configuration.isPressed {
                IconView(.play, size: 32).foregroundStyle(.white)
                    .frame(width: 68, height: 48)
                    .background(RoundedRectangle(cornerRadius: 14).fill(HT.accent))
            }
        }
    }
}

// MARK: - owner row and actions

private struct Owner: View {
    let video: Video
    @Environment(Library.self) private var lib
    @Environment(\.openURL) private var openURL
    @Environment(\.narrow) private var narrow

    var body: some View {
        let who = VStack(alignment: .leading, spacing: 0) {
            Text(video.channel ?? "").font(.system(size: 16, weight: .medium))
            Text(video.recLine).font(.system(size: 14)).foregroundStyle(HT.muted)
        }
        let actions = HStack(spacing: 8) {
            HStack(spacing: 0) {
                SegButton(icon: .like, title: "Like", on: lib.isLiked(video.vid)) { lib.toggleLike(video.vid) }
                    .accessibilityLabel("Like")
                Rectangle().fill(HT.bg3).frame(width: 1, height: 36)
                SegButton(icon: .dislike, title: nil, on: lib.isDisliked(video.vid)) { lib.toggleDislike(video.vid) }
                    .accessibilityLabel("Dislike")
            }
            .background(Capsule().fill(HT.bg2))
            .clipShape(Capsule())
            let saved = lib.isLater(video.vid)
            Pill(icon: saved ? .check : .clock, title: saved ? "Saved" : "Watch later") { lib.toggleLater(video.vid) }
            Pill(icon: .external, title: "YouTube") { openURL(youtubeURL(video.vid)) }
        }
        if narrow {
            VStack(alignment: .leading, spacing: 12) {
                who
                ScrollView(.horizontal) { actions }.scrollIndicators(.hidden)
            }
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { who; Spacer(minLength: 12); actions.fixedSize() }
                VStack(alignment: .leading, spacing: 12) { who; actions.fixedSize() }
            }
        }
    }
}

private struct SegButton: View {
    let icon: Icon
    let title: String?
    let on: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                IconView(icon, size: 20).foregroundStyle(on ? HT.good : HT.text)
                if let title { Text(title).font(.system(size: 14, weight: .medium)) }
            }
            .padding(.horizontal, 14).frame(height: 36)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
    }
}

// MARK: - description box

private struct Description: View {
    let video: Video
    @Environment(Router.self) private var router
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(video.topLine).font(.system(size: 14, weight: .medium)).padding(.bottom, 6)
            if let s = video.summary, !s.isEmpty { Text(s).ht(14).padding(.bottom, 10) }
            if let w = video.whyHn, !w.isEmpty { Text(w).ht(14).foregroundStyle(HT.muted).padding(.bottom, 10) }
            FlowLayout(spacing: 6) {
                ForEach(video.categories ?? [], id: \.id) { c in
                    Tag(text: c.name, bold: true) { router.push(.category(c.id)) }
                }
                ForEach(video.tags ?? [], id: \.self) { t in
                    Tag(text: "#" + t.replacingOccurrences(of: " ", with: "")) { router.push(.search(t, Filters())) }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(HT.bg2))
    }
}

private struct Tag: View {
    let text: String
    var bold = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(text).font(.system(size: 12, weight: bold ? .medium : .regular))
                .padding(.horizontal, 8).padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 6).fill(HT.bg3))
        }
        .buttonStyle(PressStyle())
    }
}

// MARK: - HN comments

private struct Comments: View {
    let comments: [Comment]
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(comments.count) comment\(comments.count == 1 ? "" : "s") from Hacker News")
                .font(.system(size: 20, weight: .bold))
                .padding(.top, 24).padding(.bottom, 16)
            ForEach(comments) { m in
                VStack(alignment: .leading, spacing: 0) {
                    (Text("@\(m.author)").fontWeight(.medium).foregroundColor(HT.text)
                     + Text(" \(m.year) · in “\(m.story ?? "")”"))
                        .font(.system(size: 12)).foregroundStyle(HT.muted)
                        .padding(.bottom, 2)
                    Text(commentText(m.collapsedText)).ht(14).padding(.bottom, 6)
                        .textSelection(.enabled)
                    HStack(spacing: 12) {
                        let strong = m.stance == "strong_rec"
                        Text(stanceLabels[m.stance ?? ""] ?? "")
                            .fontWeight(strong ? .medium : .regular)
                            .foregroundStyle(strong ? HT.text : HT.muted)
                        Button("View on HN") { openURL(hnURL(m.id)) }
                            .buttonStyle(.plain)
                            .foregroundStyle(HT.muted)
                    }
                    .font(.system(size: 12))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 20)
            }
        }
    }

    /// Turns the [VIDEO] / [LINK] markers into the site's small inline labels.
    private func commentText(_ t: String) -> AttributedString {
        var out = AttributedString()
        var rest = Substring(t)
        while let r = rest.range(of: #"\[(VIDEO|LINK)\]"#, options: .regularExpression) {
            out += AttributedString(String(rest[..<r.lowerBound]))
            let video = rest[r] == "[VIDEO]"
            var mark = AttributedString(video ? "▶ this video" : "link")
            mark.foregroundColor = video ? HT.text : HT.muted
            if video { mark.font = .system(size: 14, weight: .medium) }
            out += mark
            rest = rest[r.upperBound...]
        }
        out += AttributedString(String(rest))
        return out
    }
}

// MARK: - the player

/// YouTube's privacy-enhanced embed, as on the site. Loaded from an HTML page with a hackertube.org base URL
/// so the embed gets a referrer (YouTube refuses to play embeds without one).
struct YouTubePlayer: UIViewRepresentable {
    let vid: String
    let autoplay: Bool

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsPictureInPictureMediaPlayback = true
        let web = WKWebView(frame: .zero, configuration: config)
        web.isOpaque = false
        web.backgroundColor = .black
        web.scrollView.isScrollEnabled = false
        web.navigationDelegate = context.coordinator
        web.uiDelegate = context.coordinator
        let src = "https://www.youtube-nocookie.com/embed/\(vid)?rel=0&playsinline=1\(autoplay ? "&autoplay=1" : "")"
        let html = """
        <!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1">
        <meta name="referrer" content="strict-origin-when-cross-origin">
        <style>html,body{margin:0;height:100%;background:#000;overflow:hidden}iframe{width:100%;height:100%;border:0;display:block}</style>
        </head><body><iframe src="\(src)" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; fullscreen"
        referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe></body></html>
        """
        web.loadHTMLString(html, baseURL: URL(string: "https://hackertube.org/"))
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        // Links out of the player (the YouTube logo, "Watch on YouTube") open outside the app.
        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if action.targetFrame?.isMainFrame == true, action.navigationType == .linkActivated, let url = action.request.url {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                     for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if let url = action.request.url { UIApplication.shared.open(url) }
            return nil
        }
    }
}
