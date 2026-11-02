import SwiftUI
import UIKit
import Darwin

/// Legacy WebKit runs on its own "web thread". When a media seek finishes, it reports back on the main run loop
/// without taking the web-thread lock and trips an internal thread check. Holding the lock on the main thread
/// at the start of every run-loop pass (WebKit releases it before the main thread goes idle) makes that
/// callback run under the lock, as WebKit expects.
private enum WebThreadGuard {
    private typealias Fn = @convention(c) () -> Void
    private static let lock: Fn? = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "WebThreadLock").map { unsafeBitCast($0, to: Fn.self) }
    private static var observer: CFRunLoopObserver?
    private static var users = 0

    static func retain() {
        users += 1
        guard observer == nil, let lock else { return }
        let o = CFRunLoopObserverCreateWithHandler(nil, CFRunLoopActivity.beforeSources.rawValue | CFRunLoopActivity.beforeTimers.rawValue,
                                                   true, 0) { _, _ in lock() }
        CFRunLoopAddObserver(CFRunLoopGetMain(), o, .commonModes)
        observer = o
    }

    static func release() {
        users = max(0, users - 1)
        guard users == 0, let o = observer else { return }
        CFRunLoopRemoveObserver(CFRunLoopGetMain(), o, .commonModes)
        observer = nil
    }
}

/// Plays a video with YouTube's own IFrame player, inside the app.
/// tvOS has no public web view; the legacy `UIWebView` class still ships in the OS, so it is created at runtime.
/// YouTube's player takes care of streams and tokens itself, exactly as in the iOS app's embed.
final class YouTubeWebPlayerView: UIView {
    private var web: UIView?

    /// False when this OS has no web view to play in (then the caller falls back to the YouTube app).
    static var isAvailable: Bool { NSClassFromString("UIWebView") is UIView.Type }

    init(vid: String) {
        super.init(frame: .zero)
        backgroundColor = .black
        guard let cls = NSClassFromString("UIWebView") as? UIView.Type else { return }
        WebThreadGuard.retain()
        let web = cls.init(frame: .zero)
        web.backgroundColor = .black
        web.isOpaque = true
        web.isUserInteractionEnabled = false   // the remote drives the player through JavaScript
        web.setValue(true, forKey: "allowsInlineMediaPlayback")
        web.setValue(false, forKey: "mediaPlaybackRequiresUserAction")
        if let scroll = web.value(forKey: "scrollView") as? UIScrollView {
            // edge to edge: no overscan safe-area inset, no scrolling
            scroll.contentInsetAdjustmentBehavior = .never
            scroll.isScrollEnabled = false
            scroll.contentInset = .zero
        }
        web.translatesAutoresizingMaskIntoConstraints = false
        addSubview(web)
        NSLayoutConstraint.activate([
            web.leadingAnchor.constraint(equalTo: leadingAnchor), web.trailingAnchor.constraint(equalTo: trailingAnchor),
            web.topAnchor.constraint(equalTo: topAnchor), web.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        self.web = web
        // a hackertube.org base URL gives the embed a referrer, which YouTube requires
        _ = web.perform(NSSelectorFromString("loadHTMLString:baseURL:"), with: Self.html(vid), with: URL(string: "https://hackertube.org/"))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }


    deinit {
        if web != nil { DispatchQueue.main.async { WebThreadGuard.release() } }
    }

    @discardableResult
    func js(_ script: String) -> String {
        guard let web else { return "" }
        let r = web.perform(NSSelectorFromString("stringByEvaluatingJavaScriptFromString:"), with: script)
        return r?.takeUnretainedValue() as? String ?? ""
    }

    /// The YouTube IFrame API with YouTube's controls off: the app draws TV controls instead.
    private static func html(_ vid: String) -> String {
        """
        <!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1">
        <style>html,body{margin:0;width:100%;height:100%;background:#000;overflow:hidden}#p{position:absolute;inset:0;width:100%;height:100%}</style>
        </head><body><div id="p"></div>
        <script>
        window.htState = -2; window.htError = 0; var player;
        function onYouTubeIframeAPIReady() {
          player = new YT.Player('p', { width: '100%', height: '100%', videoId: '\(vid)', host: 'https://www.youtube-nocookie.com',
            playerVars: { autoplay: 1, playsinline: 1, rel: 0, controls: 0, iv_load_policy: 3, fs: 0, disablekb: 1 },
            events: {
              onReady: function (e) { window.htState = -1; e.target.playVideo(); },
              onStateChange: function (e) { window.htState = e.data; },
              onError: function (e) { window.htError = e.data || 1; }
            } });
        }
        function htStatus() {
          if (!player || !player.getCurrentTime) return [htState, htError, 0, 0].join(',');
          return [htState, htError, player.getCurrentTime() || 0, player.getDuration() || 0].join(',');
        }
        </script>
        <script src="https://www.youtube.com/iframe_api"></script>
        </body></html>
        """
    }
}

/// Owns the web player and mirrors its state for SwiftUI.
@MainActor @Observable
final class TVPlayerModel {
    let view: YouTubeWebPlayerView
    /// YouTube player states: -2 loading, -1 unstarted, 0 ended, 1 playing, 2 paused, 3 buffering, 5 cued.
    private(set) var state = -2
    private(set) var error = 0
    private(set) var time: Double = 0
    private(set) var duration: Double = 0
    private(set) var started = false

    init(vid: String) { view = YouTubeWebPlayerView(vid: vid) }

    func poll() {
        let parts = view.js("htStatus()").split(separator: ",").map { Double($0) ?? 0 }
        guard parts.count == 4 else { return }
        state = Int(parts[0]); error = Int(parts[1])
        if !seeking { time = parts[2] }
        duration = parts[3]
        if state == 1 { started = true }
    }

    var playing: Bool { state == 1 || state == 3 }

    func togglePlay() {
        view.js(playing ? "player.pauseVideo()" : "player.playVideo()")
        state = playing ? 2 : 1
    }

    private var seeking = false
    func seek(by delta: Double) {
        guard duration > 0 else { return }
        time = min(max(0, time + delta), duration - 1)
        seeking = true
        view.js("player.seekTo(\(time), true)")
        Task { try? await Task.sleep(for: .milliseconds(800)); seeking = false }
    }

    func stop() { view.js("player && player.stopVideo && player.stopVideo()") }
}

private struct PlayerHost: UIViewRepresentable {
    let view: YouTubeWebPlayerView
    func makeUIView(context: Context) -> YouTubeWebPlayerView { view }
    func updateUIView(_ v: YouTubeWebPlayerView, context: Context) {}
}

/// Full-screen player: Play/Pause or Select to pause, ← → to skip 10 seconds, Menu to close.
struct TVPlayerScreen: View {
    let video: Video
    @State private var model: TVPlayerModel
    @State private var overlayUntil = Date().addingTimeInterval(4)
    @State private var now = Date()
    @Environment(TVRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    init(video: Video) {
        self.video = video
        _model = State(initialValue: TVPlayerModel(vid: video.vid))
    }

    private var showOverlay: Bool { !model.started || !model.playing || now < overlayUntil }

    var body: some View {
        ZStack {
            Color.black
            PlayerHost(view: model.view)
            if !model.started {
                // the video's frame until YouTube's player starts
                VideoImage(vid: video.vid).overlay(Color.black.opacity(0.35))
                ProgressView().scaleEffect(1.6)
            }
            if model.started && !model.playing && model.state != 3 {
                IconView(.play, size: 72).foregroundStyle(.white)
                    .frame(width: 160, height: 112)
                    .background(RoundedRectangle(cornerRadius: 32).fill(Color.black.opacity(0.7)))
            }
            controls.opacity(showOverlay ? 1 : 0).animation(.easeOut(duration: 0.25), value: showOverlay)
        }
        .ignoresSafeArea()
        .focusable()
        .focusEffectDisabled()
        .onTapGesture { model.togglePlay(); poke() }
        .onPlayPauseCommand { model.togglePlay(); poke() }
        .onMoveCommand { dir in
            switch dir {
            case .left: model.seek(by: -10)
            case .right: model.seek(by: 10)
            default: break
            }
            poke()
        }
        .onExitCommand { close() }
        .task {
            while !Task.isCancelled {
                model.poll()
                now = Date()
                if model.error != 0 {
                    // the uploader turned off embedding (errors 101/150) or the video can't play: hand over to YouTube
                    close()
                    router.openInYouTubeApp(video.vid)
                    return
                }
                if model.state == 0 && model.started { close(); return }
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }

    private func poke() { overlayUntil = Date().addingTimeInterval(4); now = Date() }

    private func close() {
        model.stop()
        dismiss()
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
            VStack(alignment: .leading, spacing: 18) {
                Text(video.title).font(.system(size: 40, weight: .bold)).lineLimit(2).foregroundStyle(.white)
                Text(video.channel ?? "").font(.system(size: 26)).foregroundStyle(.white.opacity(0.7))
                GeometryReader { g in
                    let f = model.duration > 0 ? min(1, model.time / model.duration) : 0
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.3))
                        Capsule().fill(HT.accent).frame(width: max(10, g.size.width * f))
                    }
                }
                .frame(height: 10)
                .padding(.top, 10)
                HStack {
                    Text(formatClock(model.time))
                    Spacer()
                    Text("-" + formatClock(max(0, model.duration - model.time)))
                }
                .font(.system(size: 24, weight: .medium).monospacedDigit())
                .foregroundStyle(.white.opacity(0.8))
            }
            .padding(.horizontal, 90).padding(.bottom, 70).padding(.top, 140)
            .background(LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .top, endPoint: .bottom))
        }
    }
}

private func formatClock(_ t: Double) -> String {
    let s = Int(t.rounded(.down))
    return s >= 3600 ? String(format: "%d:%02d:%02d", s / 3600, s % 3600 / 60, s % 60) : String(format: "%d:%02d", s / 60, s % 60)
}
