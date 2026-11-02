import SwiftUI

/// A video's page: frame, Play (in the app), Like / Not for me / Watch later, the summary, why HN likes it,
/// its categories, Up next, and what Hacker News said about it.
struct TVVideoPage: View {
    let vid: String
    @State private var page: VideoPage?
    @State private var related: [Video]?
    @State private var failed = false
    @Environment(Library.self) private var lib
    @Environment(TVRouter.self) private var router
    @FocusState private var playFocused: Bool

    var body: some View {
        TVPage {
            if let page { content(page) } else { TVStatus(text: failed ? "Not found." : "Loading…") }
        }
        .task {
            guard page == nil else { return }
            do {
                let p = try await API.video(vid)
                page = p
                lib.markSeen(vid)
                playFocused = true
            } catch { failed = true; return }
            related = try? await API.related(vid)
        }
    }

    @ViewBuilder private func content(_ data: VideoPage) -> some View {
        let d = data.video
        HStack(alignment: .top, spacing: 56) {
            TVThumb(video: d).frame(width: 720)
            VStack(alignment: .leading, spacing: 0) {
                Text(d.title).font(.system(size: 44, weight: .bold)).lineLimit(3)
                HStack(alignment: .firstTextBaseline, spacing: 14) {
                    Text(d.channel ?? "").font(.system(size: 24, weight: .semibold))
                    Text(d.recLine).font(.system(size: 24)).foregroundStyle(HT.muted)
                }
                .padding(.top, 14).padding(.bottom, 28)
                FlowLayout(spacing: 20, lineSpacing: 20) {
                    TVPill(icon: .play, title: "Play") { router.play(d) }
                        .focused($playFocused)
                    TVPill(icon: .external, title: "YouTube") { router.openInYouTubeApp(d.vid) }
                    TVPill(icon: .like, title: lib.isLiked(d.vid) ? "Liked" : "Like", on: lib.isLiked(d.vid)) { lib.toggleLike(d.vid) }
                    TVPill(icon: .dislike, title: "Not for me", on: lib.isDisliked(d.vid)) { lib.toggleDislike(d.vid) }
                    TVPill(icon: lib.isLater(d.vid) ? .check : .clock, title: lib.isLater(d.vid) ? "Saved" : "Watch later") { lib.toggleLater(d.vid) }
                }
                .focusSection()
                Text(d.topLine).font(.system(size: 24)).foregroundStyle(HT.muted).padding(.top, 28)
            }
        }
        .padding(.bottom, 44)

        if let s = d.summary, !s.isEmpty { Text(s).font(.system(size: 30)).lineSpacing(6).padding(.bottom, 14) }
        if let w = d.whyHn, !w.isEmpty { Text(w).font(.system(size: 26)).foregroundStyle(HT.muted).lineSpacing(4).padding(.bottom, 28) }
        if let cats = d.categories, !cats.isEmpty {
            HStack(spacing: 20) {
                ForEach(cats, id: \.id) { c in TVPill(title: c.name, radius: 14) { router.push(.category(c.id)) } }
            }
            .focusSection()
            .padding(.bottom, 56)
        }

        if let related, !related.isEmpty {
            Text("Up next").font(.system(size: 36, weight: .bold)).padding(.bottom, 28)
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 48) {
                    ForEach(related) { v in TVCard(video: v).frame(width: 400) }
                }
                .padding(.vertical, 12)
            }
            .scrollClipDisabled()
            .scrollIndicators(.hidden)
            .focusSection()
            .padding(.bottom, 56)
        }

        Text("\(data.comments.count) comment\(data.comments.count == 1 ? "" : "s") from Hacker News")
            .font(.system(size: 36, weight: .bold)).padding(.bottom, 28)
        LazyVStack(alignment: .leading, spacing: 24) {
            ForEach(data.comments) { TVCommentRow(comment: $0) }
        }
        .frame(maxWidth: 1400, alignment: .leading)
    }
}

/// Comments are focusable so the remote can scroll through them.
struct TVCommentRow: View {
    let comment: Comment
    var body: some View {
        Button {} label: {
            VStack(alignment: .leading, spacing: 10) {
                (Text("@\(comment.author)").fontWeight(.semibold) + Text("  \(comment.year) · in “\(comment.story ?? "")”").foregroundColor(HT.muted))
                    .font(.system(size: 22))
                Text(markers(comment.collapsedText)).font(.system(size: 26)).lineSpacing(5)
                Text(stanceLabels[comment.stance ?? ""] ?? "")
                    .font(.system(size: 22, weight: comment.stance == "strong_rec" ? .semibold : .regular))
                    .opacity(comment.stance == "strong_rec" ? 1 : 0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(TVCommentStyle())
    }

    private func markers(_ t: String) -> AttributedString {
        var out = AttributedString()
        var rest = Substring(t)
        while let r = rest.range(of: #"\[(VIDEO|LINK)\]"#, options: .regularExpression) {
            out += AttributedString(String(rest[..<r.lowerBound]))
            let video = rest[r] == "[VIDEO]"
            var mark = AttributedString(video ? "▶ this video" : "link")
            if video { mark.font = .system(size: 26, weight: .semibold) } else { mark.foregroundColor = HT.muted }
            out += mark
            rest = rest[r.upperBound...]
        }
        out += AttributedString(String(rest))
        return out
    }
}

private struct TVCommentStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { StyledBody(configuration: configuration) }
    private struct StyledBody: View {
        let configuration: Configuration
        @Environment(\.isFocused) private var focused
        var body: some View {
            configuration.label
                .foregroundStyle(HT.text)
                .padding(28)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(focused ? HT.bg3 : HT.bg2))
                .scaleEffect(focused ? 1.01 : 1)
                .animation(.easeOut(duration: 0.15), value: focused)
        }
    }
}
