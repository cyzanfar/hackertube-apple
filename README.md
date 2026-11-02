# HackerTube for iPhone, iPad and Apple TV

Native SwiftUI apps for [hackertube.org](https://hackertube.org): the YouTube videos Hacker News keeps telling each other to watch. Same pages, same design tokens, same icons and the same API as the website. Not affiliated with HackerTube.

## Build

Requires Xcode 16+ (iOS 17 / tvOS 17 deployment targets) and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
xcodegen generate          # writes HackerTube.xcodeproj from project.yml
open HackerTube.xcodeproj  # schemes: HackerTube (iOS/iPadOS), HackerTubeTV (tvOS)
```

To run on a device, set your team under Signing & Capabilities. Bundle ids are `com.cyzanfar.hackertube.ios` and `com.cyzanfar.hackertube.tv`.

## Layout

| Folder | What |
|---|---|
| `Shared/` | API client (`/api/feed`, `list`, `search`, `video`, `related`, `docs`, `browse`, `playlists`, `playlist`, `stats`, `export`), models, local library (likes, dislikes, Watch later, history in UserDefaults, like the site's localStorage), formatting, design tokens, the site's SVG icons with a small SVG-path parser, frame thumbnails |
| `iOS/` | The website as an app: top bar, sidebar (a drawer below 800pt, like the site), filters, Home / Longs / Liked / History / Watch later / Categories / Playlists / Settings / About / Data, search, watch page with the privacy-enhanced YouTube embed and HN comments |
| `tvOS/` | Apple TV, modeled on [hackertube.tv](https://github.com/ephraimduncan/hackertube.tv): icon rail that expands on focus, area chips on Home, video pages with Play, YouTube, Like, Not for me, Watch later, Up next and HN comments. Videos play inside the app (see below) |
| `scripts/` | `make_icons.swift` renders the app icons and tvOS brand assets; `shot.sh` relaunches the app in a simulator and takes a screenshot |

## Playback on Apple TV

tvOS has no public web view, so the TV app creates the legacy `UIWebView` class (still present in tvOS) at runtime and runs YouTube's own IFrame player in it, full screen, with TV controls drawn by the app: Play/Pause or Select to pause, ← → to skip 10 seconds, Menu to close (`tvOS/TVWebPlayer.swift`).

- **Seeking:** legacy WebKit reports a finished media seek on the main run loop without its web-thread lock, which trips an internal assertion and crashes. While a video plays, the app takes that lock (`WebThreadLock`) at the start of each main run-loop pass, and WebKit releases it before the thread idles, so the callback runs under the lock.
- **Quality:** legacy WebKit on tvOS is built without Media Source Extensions, so YouTube serves its 360p stream. The **YouTube** button, or Settings → Play videos in → YouTube app, hands videos to the YouTube app for HD.
- **Fallbacks:** if the uploader blocks embedding, the video goes to the YouTube app, and without that app a QR code opens it on your phone.
- **App Store:** `UIWebView` and `WebThreadLock` are private on tvOS. Fine for personal installs, TestFlight-style ad hoc builds and sideloading; App Store review would reject it. For an App Store build, set Play videos in → YouTube app as the only path.

## Testing hooks

Launch arguments open a page directly. iOS: `-route watch/<id>` (also `search/<q>`, `c/<id>`, `a/<id>`, `p/<slug>`, `categories`, `playlists`, `longs`, `about`, `data`, `settings`), `-filtersOpen`, `-play`. tvOS: `-tab <home|search|categories|…>`, `-video <id>`, `-playlist <slug>`, `-play <id>` (opens the player), `-sidebar`.
