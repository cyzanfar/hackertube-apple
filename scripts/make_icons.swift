// Renders the app icons and tvOS brand assets from the site's favicon and wordmark.
// Usage: swift scripts/make_icons.swift   (from the repo root)
import AppKit

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let orange = NSColor(srgbRed: 1, green: 0.4, blue: 0, alpha: 1)
let dark = NSColor(srgbRed: 15 / 255, green: 15 / 255, blue: 15 / 255, alpha: 1)
let light = NSColor(srgbRed: 241 / 255, green: 241 / 255, blue: 241 / 255, alpha: 1)

func png(_ w: Int, _ h: Int, opaque: Bool = true, _ draw: (CGContext) -> Void) -> Data {
    let info = opaque ? CGImageAlphaInfo.noneSkipLast.rawValue : CGImageAlphaInfo.premultipliedLast.rawValue
    let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: info)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
    draw(ctx)
    NSGraphicsContext.restoreGraphicsState()
    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    return rep.representation(using: .png, properties: [:])!
}

func text(_ s: String, size: CGFloat, color: NSColor, kern: CGFloat = 0) -> NSAttributedString {
    NSAttributedString(string: s, attributes: [.font: NSFont.systemFont(ofSize: size, weight: .bold),
                                               .foregroundColor: color, .kern: kern])
}

func drawCentered(_ a: NSAttributedString, in rect: CGRect) {
    let size = a.size()
    a.draw(at: CGPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2 - a.size().height * 0.02))
}

/// The favicon: orange square + white bold H (rounded corners optional; iOS rounds them itself).
func logo(_ ctx: CGContext, rect: CGRect, rounded: Bool) {
    let path = rounded ? NSBezierPath(roundedRect: rect, xRadius: rect.width * 7 / 32, yRadius: rect.width * 7 / 32)
                       : NSBezierPath(rect: rect)
    orange.setFill(); path.fill()
    drawCentered(text("H", size: rect.width * 22 / 32, color: .white), in: rect)
}

/// Logo + "Hacker" + orange "Tube", centered.
func lockup(_ rect: CGRect, height: CGFloat, wordColor: NSColor) {
    let logoSize = height
    let word = NSMutableAttributedString(attributedString: text("Hacker", size: height * 0.62, color: wordColor, kern: -height * 0.025))
    word.append(text("Tube", size: height * 0.62, color: orange, kern: -height * 0.025))
    let gap = height * 0.32
    let total = logoSize + gap + word.size().width
    let x0 = rect.midX - total / 2
    let logoRect = CGRect(x: x0, y: rect.midY - logoSize / 2, width: logoSize, height: logoSize)
    logo(NSGraphicsContext.current!.cgContext, rect: logoRect, rounded: true)
    let ws = word.size()
    word.draw(at: CGPoint(x: x0 + logoSize + gap, y: rect.midY - ws.height / 2))
}

func write(_ data: Data, _ path: String) {
    let url = root.appendingPathComponent(path)
    try! FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try! data.write(to: url)
}

func json(_ obj: Any, _ path: String) {
    write(try! JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]), path)
}

let info = ["author": "xcode", "version": 1] as [String: Any]

// MARK: iOS

let ios = "iOS/Assets.xcassets"
json(["info": info], "\(ios)/Contents.json")
write(png(1024, 1024) { _ in logo(NSGraphicsContext.current!.cgContext, rect: CGRect(x: 0, y: 0, width: 1024, height: 1024), rounded: false) },
      "\(ios)/AppIcon.appiconset/icon-1024.png")
json(["images": [["filename": "icon-1024.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"]], "info": info],
     "\(ios)/AppIcon.appiconset/Contents.json")
json(["colors": [["idiom": "universal", "color": ["color-space": "srgb", "components": ["red": "0xFF", "green": "0x66", "blue": "0x00", "alpha": "1.000"]]]], "info": info],
     "\(ios)/AccentColor.colorset/Contents.json")

// MARK: tvOS brand assets

let tv = "tvOS/Assets.xcassets"
let brand = "\(tv)/App Icon & Top Shelf Image.brandassets"
json(["info": info], "\(tv)/Contents.json")

/// A layered app icon: dark back layer, logo + wordmark front layer.
func imageStack(_ name: String, _ w: Int, _ h: Int, scales: [Int]) {
    let dir = "\(brand)/\(name).imagestack"
    json(["info": info, "layers": [["filename": "Front.imagestacklayer"], ["filename": "Back.imagestacklayer"]]], "\(dir)/Contents.json")
    for layer in ["Front", "Back"] {
        json(["info": info], "\(dir)/\(layer).imagestacklayer/Contents.json")
        var images: [[String: Any]] = []
        for s in scales {
            let file = "\(layer.lowercased())@\(s)x.png"
            let W = w * s, H = h * s
            let data = layer == "Back"
                ? png(W, H) { _ in dark.setFill(); NSBezierPath(rect: CGRect(x: 0, y: 0, width: W, height: H)).fill() }
                : png(W, H, opaque: false) { _ in lockup(CGRect(x: 0, y: 0, width: W, height: H), height: CGFloat(H) * 0.3, wordColor: light) }
            write(data, "\(dir)/\(layer).imagestacklayer/Content.imageset/\(file)")
            images.append(["filename": file, "idiom": "tv", "scale": "\(s)x"])
        }
        json(["images": images, "info": info], "\(dir)/\(layer).imagestacklayer/Content.imageset/Contents.json")
    }
}

func topShelf(_ name: String, _ w: Int, _ h: Int) {
    let dir = "\(brand)/\(name).imageset"
    var images: [[String: Any]] = []
    for s in [1, 2] {
        let file = "shelf@\(s)x.png"
        let W = w * s, H = h * s
        write(png(W, H) { _ in
            dark.setFill(); NSBezierPath(rect: CGRect(x: 0, y: 0, width: W, height: H)).fill()
            lockup(CGRect(x: 0, y: 0, width: W, height: H), height: CGFloat(H) * 0.16, wordColor: light)
        }, "\(dir)/\(file)")
        images.append(["filename": file, "idiom": "tv", "scale": "\(s)x"])
    }
    json(["images": images, "info": info], "\(dir)/Contents.json")
}

imageStack("App Icon", 400, 240, scales: [1, 2])
imageStack("App Icon - App Store", 1280, 768, scales: [1])
topShelf("Top Shelf Image", 1920, 720)
topShelf("Top Shelf Image Wide", 2320, 720)
json(["info": info, "assets": [
    ["filename": "App Icon - App Store.imagestack", "idiom": "tv", "role": "primary-app-icon", "size": "1280x768"],
    ["filename": "App Icon.imagestack", "idiom": "tv", "role": "primary-app-icon", "size": "400x240"],
    ["filename": "Top Shelf Image Wide.imageset", "idiom": "tv", "role": "top-shelf-image-wide", "size": "2320x720"],
    ["filename": "Top Shelf Image.imageset", "idiom": "tv", "role": "top-shelf-image", "size": "1920x720"],
]], "\(brand)/Contents.json")
json(["colors": [["idiom": "universal", "color": ["color-space": "srgb", "components": ["red": "0xFF", "green": "0x66", "blue": "0x00", "alpha": "1.000"]]]], "info": info],
     "\(tv)/AccentColor.colorset/Contents.json")
print("icons written")
