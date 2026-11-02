import SwiftUI

/// The exact 24×24 SVG icons from hackertube.org.
enum Icon: String {
    case menu = "M3 6h18v2H3zm0 5h18v2H3zm0 5h18v2H3z"
    case search = "M20.87 20.17l-5.59-5.59A6.95 6.95 0 0 0 17 10a7 7 0 1 0-7 7c1.75 0 3.35-.64 4.58-1.71l5.59 5.59.7-.71zM10 16a6 6 0 1 1 0-12 6 6 0 0 1 0 12z"
    case about = "M11 18h2v-2h-2v2zm1-16C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8zm0-14c-2.21 0-4 1.79-4 4h2c0-1.1.9-2 2-2s2 .9 2 2c0 2-3 1.75-3 5h2c0-2.25 3-2.5 3-5 0-2.21-1.79-4-4-4z"
    case theme = "M12 3a9 9 0 1 0 9 9c0-.46-.04-.92-.1-1.36a5.39 5.39 0 0 1-4.4 2.26 5.4 5.4 0 0 1-3.14-9.8c-.44-.06-.9-.1-1.36-.1z"
    case home = "M4 21V10.08l8-6.96 8 6.96V21h-6v-6h-4v6H4z"
    case longs = "M3 6h18v12H3zm2 2v8h14V8zm4 1.5v5l4.5-2.5z"
    case liked = "M18.77 11h-4.23l1.52-4.94C16.38 5.03 15.54 4 14.38 4c-.58 0-1.14.24-1.52.65L7 11H3v10h4h1h9.43c1.06 0 1.98-.67 2.19-1.61l1.34-6c.27-1.24-.78-2.39-2.19-2.39zM7 20H4v-8h3v8z"
    case history = "M13 3a9 9 0 0 0-9 9H1l3.89 3.89.07.14L9 12H6c0-3.87 3.13-7 7-7s7 3.13 7 7-3.13 7-7 7c-1.93 0-3.68-.79-4.94-2.06l-1.42 1.42A8.954 8.954 0 0 0 13 21a9 9 0 0 0 0-18zm-1 5v5l4.28 2.54.72-1.21-3.5-2.08V8H12z"
    case clock = "M14.97 16.95 10 13.87V7h2v5.76l4.03 2.49-1.06 1.7zM12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8z"
    case categories = "M4 4h7v7H4zm2 2v3h3V6zm7-2h7v7h-7zm2 2v3h3V6zM4 13h7v7H4zm2 2v3h3v-3zm7-2h7v7h-7zm2 2v3h3v-3z"
    case playlists = "M3 6h12v2H3zm0 4h12v2H3zm0 4h8v2H3zm12 0v6l5-3z"
    case settings = "M19.14 12.94c.04-.31.06-.62.06-.94s-.02-.63-.06-.94l2.03-1.58a.49.49 0 0 0 .12-.61l-1.92-3.32a.49.49 0 0 0-.59-.22l-2.39.96c-.5-.38-1.03-.7-1.62-.94l-.36-2.54a.48.48 0 0 0-.48-.41h-3.84c-.24 0-.43.17-.47.41l-.36 2.54c-.59.24-1.13.57-1.62.94l-2.39-.96a.49.49 0 0 0-.59.22L2.74 8.87c-.12.21-.08.47.12.61l2.03 1.58c-.04.31-.06.63-.06.94s.02.63.06.94l-2.03 1.58a.49.49 0 0 0-.12.61l1.92 3.32c.12.22.37.29.59.22l2.39-.96c.5.38 1.03.7 1.62.94l.36 2.54c.05.24.24.41.48.41h3.84c.24 0 .44-.17.47-.41l.36-2.54c.59-.24 1.13-.56 1.62-.94l2.39.96c.22.08.47 0 .59-.22l1.92-3.32a.49.49 0 0 0-.12-.61l-2.01-1.58zM12 15.6A3.6 3.6 0 1 1 12 8.4a3.6 3.6 0 0 1 0 7.2z"
    case like = "M18.77 11h-4.23l1.52-4.94C16.38 5.03 15.54 4 14.38 4c-.58 0-1.14.24-1.52.65L7 11H3v10h14.43c1.06 0 1.98-.67 2.19-1.61l1.34-6c.27-1.24-.78-2.39-2.19-2.39zM7 20H4v-8h3v8z"
    case dislike = "M17 4h-1H6.57c-1.07 0-1.98.67-2.19 1.61l-1.34 6C2.77 12.85 3.82 14 5.23 14h4.23l-1.52 4.94C7.62 19.97 8.46 21 9.62 21c.58 0 1.14-.24 1.52-.65L17 14h4V4h-4zm-6.6 15.67c-.19.21-.48.33-.78.33-.26 0-.5-.11-.63-.3-.07-.1-.15-.26-.09-.47l1.52-4.94.4-1.29H5.23c-.41 0-.8-.17-1.03-.46-.12-.15-.25-.4-.18-.72l1.34-6c.1-.47.61-.82 1.21-.82H16v8.61l-5.6 6.06zM20 13h-3V5h3v8z"
    case check = "M9 16.17 4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z"
    case external = "M19 19H5V5h7V3H5a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7h-2v7zM14 3v2h3.59l-9.83 9.83 1.41 1.41L19 6.41V10h2V3h-7z"
    case play = "M8 5v14l11-7z"
    case filters = "M15 17h6v1h-6v-1zm-4 0H3v1h8v2h1v-5h-1v2zm3-9h1V3h-1v2H3v1h11v2zm4-3v1h3V5h-3zM6 14h1V9H6v2H3v1h3v2zm4-2h11v-1H10v1z"
    case playAll = "M3 5h12v2H3zm0 4h12v2H3zm0 4h8v2H3zm12 0v8l6-4z"
    case download = "M5 20h14v-2H5v2zM19 9h-4V3H9v6H5l7 7 7-7z"
    case back = "M20 11H7.83l5.59-5.59L12 4l-8 8 8 8 1.41-1.41L7.83 13H20v-2z"
}

/// Draws an `Icon` in the current foreground color, sized like the site (24 by default).
struct IconView: View {
    let icon: Icon
    var size: CGFloat = 24
    init(_ icon: Icon, size: CGFloat = 24) {
        self.icon = icon
        self.size = size
    }
    var body: some View {
        SVGShape(d: icon.rawValue).fill(style: FillStyle(eoFill: false)).frame(width: size, height: size)
    }
}

struct SVGShape: Shape {
    let d: String
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 24
        let t = CGAffineTransform(translationX: rect.minX + (rect.width - 24 * s) / 2,
                                  y: rect.minY + (rect.height - 24 * s) / 2).scaledBy(x: s, y: s)
        return SVGPathCache.path(d).applying(t)
    }
}

private enum SVGPathCache {
    static var cache: [String: Path] = [:]
    static func path(_ d: String) -> Path {
        if let p = cache[d] { return p }
        let p = SVGPathParser.parse(d)
        cache[d] = p
        return p
    }
}

/// A small SVG path-data parser: M L H V C S Q T A Z, absolute and relative.
enum SVGPathParser {
    private enum Token { case cmd(Character), num(CGFloat) }

    private static func tokenize(_ d: String) -> [Token] {
        var out: [Token] = []
        let chars = Array(d)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if c.isLetter && c != "e" && c != "E" {
                out.append(.cmd(c)); i += 1
            } else if c.isNumber || c == "-" || c == "+" || c == "." {
                var j = i
                if chars[j] == "-" || chars[j] == "+" { j += 1 }
                var dot = false
                while j < chars.count {
                    let x = chars[j]
                    if x.isNumber { j += 1 }
                    else if x == "." && !dot { dot = true; j += 1 }
                    else if (x == "e" || x == "E") && j + 1 < chars.count {
                        j += 1
                        if chars[j] == "-" || chars[j] == "+" { j += 1 }
                    } else { break }
                }
                out.append(.num(CGFloat(Double(String(chars[i..<j])) ?? 0)))
                i = j
            } else { i += 1 }
        }
        return out
    }

    static func parse(_ d: String) -> Path {
        let tokens = tokenize(d)
        var path = Path()
        var i = 0
        var cmd: Character = "M"
        var cur = CGPoint.zero, start = CGPoint.zero
        var lastCubic: CGPoint?, lastQuad: CGPoint?

        func n() -> CGFloat { if i < tokens.count, case .num(let v) = tokens[i] { i += 1; return v }; i += 1; return 0 }

        while i < tokens.count {
            if case .cmd(let c) = tokens[i] { cmd = c; i += 1 }
            else if cmd == "Z" || cmd == "z" { i += 1; continue }
            let rel = cmd.isLowercase
            let base = rel ? cur : .zero
            var nextCubic: CGPoint?, nextQuad: CGPoint?
            switch cmd.uppercased().first! {
            case "M":
                let p = CGPoint(x: base.x + n(), y: base.y + n())
                path.move(to: p); cur = p; start = p
                cmd = rel ? "l" : "L"   // further pairs are line-tos
            case "L":
                let p = CGPoint(x: base.x + n(), y: base.y + n())
                path.addLine(to: p); cur = p
            case "H":
                let x = (rel ? cur.x : 0) + n()
                cur = CGPoint(x: x, y: cur.y); path.addLine(to: cur)
            case "V":
                let y = (rel ? cur.y : 0) + n()
                cur = CGPoint(x: cur.x, y: y); path.addLine(to: cur)
            case "C":
                let c1 = CGPoint(x: base.x + n(), y: base.y + n())
                let c2 = CGPoint(x: base.x + n(), y: base.y + n())
                let p = CGPoint(x: base.x + n(), y: base.y + n())
                path.addCurve(to: p, control1: c1, control2: c2); cur = p; nextCubic = c2
            case "S":
                let c1 = lastCubic.map { CGPoint(x: 2 * cur.x - $0.x, y: 2 * cur.y - $0.y) } ?? cur
                let c2 = CGPoint(x: base.x + n(), y: base.y + n())
                let p = CGPoint(x: base.x + n(), y: base.y + n())
                path.addCurve(to: p, control1: c1, control2: c2); cur = p; nextCubic = c2
            case "Q":
                let c = CGPoint(x: base.x + n(), y: base.y + n())
                let p = CGPoint(x: base.x + n(), y: base.y + n())
                path.addQuadCurve(to: p, control: c); cur = p; nextQuad = c
            case "T":
                let c = lastQuad.map { CGPoint(x: 2 * cur.x - $0.x, y: 2 * cur.y - $0.y) } ?? cur
                let p = CGPoint(x: base.x + n(), y: base.y + n())
                path.addQuadCurve(to: p, control: c); cur = p; nextQuad = c
            case "A":
                let rx = n(), ry = n(), rot = n(), large = n() != 0, sweep = n() != 0
                let p = CGPoint(x: base.x + n(), y: base.y + n())
                addArc(&path, from: cur, to: p, rx: rx, ry: ry, rotation: rot, large: large, sweep: sweep)
                cur = p
            case "Z":
                path.closeSubpath(); cur = start
            default:
                i += 1
            }
            lastCubic = nextCubic; lastQuad = nextQuad
        }
        return path
    }

    /// SVG elliptical arc → cubic Béziers (SVG spec, appendix F.6.5).
    private static func addArc(_ path: inout Path, from p0: CGPoint, to p1: CGPoint, rx rxIn: CGFloat, ry ryIn: CGFloat,
                               rotation: CGFloat, large: Bool, sweep: Bool) {
        var rx = abs(rxIn), ry = abs(ryIn)
        if rx == 0 || ry == 0 || p0 == p1 { path.addLine(to: p1); return }
        let phi = rotation * .pi / 180, cosP = cos(phi), sinP = sin(phi)
        let dx = (p0.x - p1.x) / 2, dy = (p0.y - p1.y) / 2
        let x1 = cosP * dx + sinP * dy, y1 = -sinP * dx + cosP * dy
        let lambda = (x1 * x1) / (rx * rx) + (y1 * y1) / (ry * ry)
        if lambda > 1 { rx *= sqrt(lambda); ry *= sqrt(lambda) }
        let num = rx * rx * ry * ry - rx * rx * y1 * y1 - ry * ry * x1 * x1
        let den = rx * rx * y1 * y1 + ry * ry * x1 * x1
        var coef = sqrt(max(0, num / den))
        if large == sweep { coef = -coef }
        let cx1 = coef * rx * y1 / ry, cy1 = -coef * ry * x1 / rx
        let cx = cosP * cx1 - sinP * cy1 + (p0.x + p1.x) / 2
        let cy = sinP * cx1 + cosP * cy1 + (p0.y + p1.y) / 2
        func angle(_ ux: CGFloat, _ uy: CGFloat, _ vx: CGFloat, _ vy: CGFloat) -> CGFloat {
            let a = atan2(ux * vy - uy * vx, ux * vx + uy * vy)
            return a
        }
        let theta1 = angle(1, 0, (x1 - cx1) / rx, (y1 - cy1) / ry)
        var delta = angle((x1 - cx1) / rx, (y1 - cy1) / ry, (-x1 - cx1) / rx, (-y1 - cy1) / ry)
        if !sweep && delta > 0 { delta -= 2 * .pi }
        if sweep && delta < 0 { delta += 2 * .pi }
        let segments = max(1, Int(ceil(abs(delta) / (.pi / 2))))
        let step = delta / CGFloat(segments)
        let t = 4 / 3 * tan(step / 4)
        func point(_ a: CGFloat) -> (CGPoint, CGPoint) {
            let ex = rx * cos(a), ey = ry * sin(a)
            let p = CGPoint(x: cx + cosP * ex - sinP * ey, y: cy + sinP * ex + cosP * ey)
            let dxa = -rx * sin(a), dya = ry * cos(a)
            let d = CGPoint(x: cosP * dxa - sinP * dya, y: sinP * dxa + cosP * dya)
            return (p, d)
        }
        var a = theta1
        for _ in 0..<segments {
            let (pa, da) = point(a)
            let (pb, db) = point(a + step)
            path.addCurve(to: pb, control1: CGPoint(x: pa.x + t * da.x, y: pa.y + t * da.y),
                          control2: CGPoint(x: pb.x - t * db.x, y: pb.y - t * db.y))
            a += step
        }
    }
}
