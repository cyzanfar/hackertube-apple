import SwiftUI
import UIKit

/// With "Video frames" on (the default), a frame from the middle of the video (hq2.jpg) instead of the
/// uploader's attention-optimized thumbnail; a missing frame falls back to the regular thumbnail.
func thumbURLs(_ vid: String, frames: Bool) -> [URL] {
    let hq2 = URL(string: "https://i.ytimg.com/vi/\(vid)/hq2.jpg")!
    let hq = URL(string: "https://i.ytimg.com/vi/\(vid)/hqdefault.jpg")!
    return frames ? [hq2, hq] : [hq]
}

private let imageCache: NSCache<NSURL, UIImage> = {
    let c = NSCache<NSURL, UIImage>()
    c.countLimit = 600
    return c
}()

/// Loads the first URL that works, caching decoded images.
@MainActor
final class ImageLoader {
    static func load(_ urls: [URL]) async -> UIImage? {
        for url in urls {
            if let img = imageCache.object(forKey: url as NSURL) { return img }
            guard let (data, resp) = try? await API.session.data(from: url),
                  (resp as? HTTPURLResponse)?.statusCode == 200 else { continue }
            let img = await Task.detached(priority: .userInitiated) {
                UIImage(data: data)?.preparingForDisplay()
            }.value
            if let img {
                imageCache.setObject(img, forKey: url as NSURL)
                return img
            }
        }
        return nil
    }
}

/// A 16:9 video image that fills and crops like `object-fit: cover` (which also trims hq2/hqdefault letterboxing).
struct VideoImage: View {
    let vid: String
    @Environment(Library.self) private var lib
    @State private var image: UIImage?

    var body: some View {
        let urls = thumbURLs(vid, frames: lib.frames)
        HT.bg2
            .overlay {
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                }
            }
            .clipped()
            .task(id: urls) {
                image = await ImageLoader.load(urls)
            }
    }
}
