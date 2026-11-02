import SwiftUI

/// Inline **bold** and [links](…) from markdown, with links in the site's blue.
private func md(_ s: String) -> AttributedString {
    var a = (try? AttributedString(markdown: s, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(s)
    for run in a.runs where run.link != nil { a[run.range].foregroundColor = HT.good }
    return a
}

private struct Para: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View { Text(md(text)).ht(15, line: 24).padding(.bottom, 12).fixedSize(horizontal: false, vertical: true) }
}

private struct H2: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View { Text(text).font(.system(size: 20, weight: .bold)).padding(.top, 32).padding(.bottom, 8) }
}

private struct Bullets: View {
    let items: [String]
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(items, id: \.self) { s in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("•").font(.system(size: 15))
                    Text(md(s)).ht(15, line: 24).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.leading, 8).padding(.bottom, 12)
    }
}

private struct Code: View {
    let text: String
    var body: some View {
        Text(text).font(.system(size: 13, design: .monospaced))
            .padding(.horizontal, 5).padding(.vertical, 1)
            .background(RoundedRectangle(cornerRadius: 4).fill(HT.bg2))
    }
}

// MARK: - /about

struct AboutPage: View {
    @State private var stats: Stats?
    @State private var export: ExportInfo?
    @Environment(Router.self) private var router

    var body: some View {
        PageScroll(maxWidth: 720) {
            VStack(alignment: .leading, spacing: 0) {
                Wordmark(size: 32).padding(.top, 32).padding(.bottom, 8)
                Text("The YouTube videos that Hacker News keeps telling each other to watch.")
                    .ht(18, line: 28).foregroundStyle(HT.muted).padding(.bottom, 24)
                if let s = stats { content(s) } else { StatusText(text: "Loading…") }
            }
            .padding(.bottom, 48)
        }
        .task {
            guard stats == nil else { return }
            async let s = API.stats()
            async let e = API.export()
            export = try? await e
            stats = try? await s
        }
    }

    private func rows(_ name: String) -> Int? { export?.files?.first { $0.name == name }?.rows }
    private func size(_ name: String) -> String { export?.files?.first { $0.name == name }.map { formatMB($0.bytes) } ?? "" }

    @ViewBuilder private func content(_ s: Stats) -> some View {
        let first = s.firstYear ?? "", last = s.lastYear ?? ""
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
            stat(formatNumber(s.videos), "videos")
            stat(formatNumber(s.comments), "HN comments read")
            stat(formatNumber(s.categories ?? 0), "topics in \(s.areas ?? 0) areas")
            stat("\(first)–\(last)", "years of HN")
        }
        .padding(.vertical, 8)

        H2("Why")
        Para("YouTube's recommendations are tuned for watch time. They're very good at finding the next thing you'll click, and not so good at finding the talk you'll still be thinking about next year.")
        Para("Meanwhile, for nearly two decades, Hacker News commenters have been pointing each other at exactly those videos: the conference talk that changed how someone writes software, the lecture series that finally made a subject click, the documentary nobody else seems to know about. Those recommendations are scattered across millions of comments. HackerTube collects them in one place and makes them browsable, searchable and personal.")

        H2("How it was built")
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array([
                "**Read all of Hacker News.** Every comment from \(first) to \(last) (from a public dataset of the full HN archive) was scanned for YouTube links. That turns up well over a hundred thousand different videos.",
                "**Keep the videos HN keeps coming back to.** A video makes the cut if at least three different people linked it with some real commentary, in at least three different months. One-off links and pure drive-bys fall away, leaving roughly 7,000 videos.",
                "**Read each comment with an AI model.** A link isn't always a recommendation. Claude read each comment, along with the title of the HN story it was posted under, and judged what the commenter was doing: recommending the video, citing it as a source, using it as a joke, or criticizing it. It also picked out a short quote and a few topics.",
                "**Write a card for every video.** Using the video's YouTube details and everything HN said about it, Claude wrote a short summary, why HN people like it, what kind of video it is, and whether it has aged well. Videos are then sorted into a shared list of topics.",
                "**Rank by lasting recommendations.** A video's standing comes from how many separate months people recommended it in. Being linked again and again over the years counts for more than one viral spike.",
            ].enumerated()), id: \.offset) { i, step in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(i + 1)").font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 24, height: 24).background(Circle().fill(HT.accent))
                    Text(md(step)).ht(15, line: 24).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.bottom, 12)

        H2("What you can do")
        Bullets(items: [
            "**Home** mixes several kinds of picks: HN classics, hidden gems that HN loves but few people have watched, recent favorites, topics you haven't explored yet, and, once you like a few videos, things similar to them and things that the same HN people also recommended. Long-press a video to see why it's there.",
            "**Search** understands topics, not just keywords. Searching \"distributed systems\" finds talks that never use those words.",
            "**Browse** by topic on the Categories page, or start with one of the Playlists.",
            "**Every video page** shows what Hacker News actually said about it: the real comments, with links back to the threads.",
            "**Like**, **Watch later** and **History** work like you'd expect. Likes steer your Home feed.",
        ])

        H2("Fork it")
        Para("Everything behind this site is yours to reuse. The easiest way: **give the zip to your AI agent** (Claude Code or similar) and tell it what you want, such as a different interface, a weekly email of talks on your topics, a terminal browser, or an analysis. The zip includes a `DATA.md` written for agents: how the files fit together, the gotchas, example records, and how to walk you through getting YouTube metadata if you want it.")
        Para("The download\(export?.zip.map { " (\(formatMB($0.bytes)) zip)" } ?? "") contains:")
        let files: [(String, String)] = [
            ("videos.jsonl", "All \(formatNumber(rows("videos.jsonl") ?? s.videos)) videos: YouTube id and link, title, channel, summary, why HN likes it, type, level, shelf life, topics, categories, pull quote, HN stats and quality score"),
            ("mentions.jsonl", "All \(formatNumber(rows("mentions.jsonl") ?? s.comments)) labeled HN comments: comment id and link, author, month, story title, stance, why, quote and the cleaned comment text"),
            ("taxonomy.json", "The \(s.areas ?? 0) areas and \(s.categories ?? 0) topic categories, with synonym-rich descriptions"),
            ("related.jsonl", "\"HN people also recommend\" for \(formatNumber(rows("related.jsonl") ?? 0)) videos (counts only, no usernames)"),
            ("embeddings.npy", "The search vectors (bge-small, 384 dimensions, plus embedding_ids.json), so you get semantic search and \"similar videos\" for free"),
            ("DATA.md", "How it was made, every field explained, stance definitions, a code example, licensing"),
        ]
        FileTable(rows: files.map { ($0.0, $0.1, size($0.0)) })
        Para("It's released under ODC-By 1.0, like the Hacker News archive it comes from: use it for anything, just credit HackerTube. YouTube's own metadata (descriptions, view counts, durations) isn't included, because YouTube's terms don't allow redistributing it. Every record has the video id, so you can fetch it yourself.")
            .padding(.top, 12)
        Button { router.push(.data) } label: { Text("Download the data →").font(.system(size: 15)).foregroundStyle(HT.good) }
            .buttonStyle(.plain).padding(.bottom, 12)

        H2("Privacy")
        Para("There are no accounts. Your likes, history and Watch later list are stored only on this device. Videos play through YouTube's privacy-enhanced embed.")

        H2("Credits")
        Para("HackerTube was built by **Claude Opus 5.5**, Anthropic's AI model, working in Claude Code: the data pipeline, the search and recommendations, and this site. It was prompted into existence by [@karpathy](https://x.com/karpathy). The comment labels, video cards and topic list were written by teams of Claude Sonnet 5.5 agents that Claude Opus coordinated.")
        Text("HackerTube is an independent project. It is not affiliated with YouTube, Google, Hacker News or Y Combinator. Video data comes from the YouTube Data API, and comments from the public Hacker News archive.")
            .ht(13, line: 21).foregroundStyle(HT.muted)
    }

    private func stat(_ big: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(big).font(.system(size: 24, weight: .bold)).tracking(-0.5).lineLimit(1).minimumScaleFactor(0.6)
            Text(label).font(.system(size: 13)).foregroundStyle(HT.muted)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(HT.bg2))
    }
}

private struct FileTable: View {
    let rows: [(String, String, String)]
    var link: ((String) -> URL)? = nil
    @Environment(\.openURL) private var openURL
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(rows, id: \.0) { name, what, size in
                VStack(spacing: 0) {
                    Rectangle().fill(HT.line).frame(height: 1)
                    HStack(alignment: .top, spacing: 8) {
                        Group {
                            if let link {
                                Button { openURL(link(name)) } label: { Code(text: name).foregroundStyle(HT.good) }.buttonStyle(.plain)
                            } else { Code(text: name) }
                        }
                        .frame(minWidth: 120, alignment: .leading)
                        Text(what).font(.system(size: 14)).frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                        if !size.isEmpty { Text(size).font(.system(size: 14)).foregroundStyle(HT.muted).fixedSize() }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }
}

// MARK: - /data

struct DataPage: View {
    @State private var m: ExportInfo?
    @State private var failed = false
    @Environment(Router.self) private var router
    @Environment(\.openURL) private var openURL

    private static let notes: [String: String] = [
        "DATA.md": "How it was made, the schema of every file, licenses",
        "videos.jsonl": "One line per video: YouTube id, title, channel, summary, why HN likes it, type, topics, categories, quote, HN stats, score",
        "mentions.jsonl": "One line per labeled HN comment: id and link, author, month, story, stance, why, quote, text",
        "taxonomy.json": "Topic areas and categories, with synonym-rich descriptions",
        "related.jsonl": "Videos recommended by the same HN people (counts only)",
        "embeddings.npy": "Search vectors: float16, 384 dims (bge-small-en-v1.5), one row per video",
        "embedding_ids.json": "Which video each embedding row is",
    ]
    private static let prompt = """
    Read DATA.md in this folder. Using this data, build me a small local web app
    that shows a fresh mix of HN-recommended talks each day, lets me filter by
    topic and length, and remembers what I've watched. Walk me through getting
    a YouTube API key so you can add durations.
    """

    var body: some View {
        PageScroll(maxWidth: 720) {
            VStack(alignment: .leading, spacing: 0) {
                if let m, let files = m.files, let zip = m.zip {
                    Text("The data").font(.system(size: 32, weight: .bold)).tracking(-0.5).padding(.top, 32).padding(.bottom, 8)
                    Text("Everything behind HackerTube, free to reuse. Give it to your AI agent and build your own.")
                        .ht(18, line: 28).foregroundStyle(HT.muted).padding(.bottom, 24)
                    Pill(icon: .download, title: "Download everything (\(formatMB(zip.bytes)) zip)") {
                        openURL(URL(string: "https://hackertube.org/download/\(zip.name)")!)
                    }
                    .padding(.bottom, 12)
                    Para("\(formatNumber(m.videos ?? 0)) videos and \(formatNumber(m.mentions ?? 0)) labeled Hacker News comments, exported \(m.generated ?? "").")

                    H2("Give it to your agent")
                    Para("Unzip it, open your AI agent (Claude Code or similar) in that folder, and tell it what to build. It will read `DATA.md`, which explains the files, how they join, the gotchas and example records. If you want view counts, durations or publish dates, it will walk you through getting a free YouTube API key. For example:")
                    Text(Self.prompt).font(.system(size: 13, design: .monospaced)).lineSpacing(5)
                        .padding(.horizontal, 16).padding(.vertical, 14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(HT.bg2))
                        .textSelection(.enabled)
                        .padding(.top, 12).padding(.bottom, 8)
                    Pill(title: "Copy this prompt") {
                        UIPasteboard.general.string = Self.prompt
                        router.showToast("Prompt copied")
                    }
                    .padding(.bottom, 12)
                    Para("Prefer to do it by hand? The files are plain JSON Lines (one JSON object per line), easy to load anywhere: `pandas.read_json(path, lines=True)`, `jq`, or a five-line loop.")

                    H2("Files")
                    FileTable(rows: files.map { f in
                        let rows = (f.rows != nil && f.name.hasSuffix("jsonl")) ? " · \(formatNumber(f.rows!)) rows" : ""
                        return (f.name, (Self.notes[f.name] ?? "") + rows, formatMB(f.bytes))
                    }, link: { URL(string: "https://hackertube.org/download/\($0)")! })

                    H2("Not included")
                    Para("YouTube's own metadata (descriptions, view counts, durations, publish dates) can't be redistributed under YouTube's API terms. Every record has the video id, so you can fetch it with a free YouTube Data API key in about \(Int(ceil(Double(m.videos ?? 0) / 50))) requests. `DATA.md` has step-by-step instructions for you (5 minutes in Google Cloud) and a ready-to-run script for your agent.")

                    H2("License")
                    Para("[ODC-By 1.0](https://opendatacommons.org/licenses/by/1-0/), the same as the Hacker News archive it's derived from: use it for anything, just credit HackerTube and the [open-index/hacker-news](https://huggingface.co/datasets/open-index/hacker-news) dataset. Comments remain the work of their authors. The labels, summaries and cards were written by Claude, so expect a few to be off.")
                } else {
                    StatusText(text: failed ? "The data export hasn't been built yet." : "Loading…")
                }
            }
            .padding(.bottom, 48)
        }
        .task {
            guard m == nil else { return }
            m = try? await API.export()
            failed = m?.files == nil
        }
    }
}
