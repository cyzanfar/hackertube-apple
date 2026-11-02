import SwiftUI
import UIKit

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255,
                  blue: CGFloat(hex & 0xff) / 255, alpha: alpha)
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) { self.init(UIColor(hex: hex, alpha: alpha)) }

    /// A color that follows the light / dark appearance, like the site's CSS variables.
    static func dynamic(_ light: UIColor, _ dark: UIColor) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }
    static func dynamic(_ light: UInt32, _ dark: UInt32) -> Color {
        dynamic(UIColor(hex: light), UIColor(hex: dark))
    }
}

/// hackertube.org's design tokens (`:root` and the dark theme).
enum HT {
    static let bg = Color.dynamic(0xffffff, 0x0f0f0f)
    static let bg2 = Color.dynamic(0xf2f2f2, 0x272727)
    static let bg3 = Color.dynamic(0xe5e5e5, 0x3f3f3f)
    static let text = Color.dynamic(0x0f0f0f, 0xf1f1f1)
    static let muted = Color.dynamic(0x606060, 0xaaaaaa)
    static let line = Color.dynamic(0xe5e5e5, 0x303030)
    static let accent = Color(hex: 0xff6600)
    static let chip = bg2
    static let chipOn = Color.dynamic(0x0f0f0f, 0xf1f1f1)
    static let chipOnText = Color.dynamic(0xffffff, 0x0f0f0f)
    static let hover = Color.dynamic(UIColor(white: 0, alpha: 0.05), UIColor(white: 1, alpha: 0.08))
    static let good = Color.dynamic(0x065fd4, 0x3ea6ff)
    static let badge = Color.black.opacity(0.8)
}

/// "Hacker" + orange "Tube".
struct Wordmark: View {
    var size: CGFloat = 20
    var body: some View {
        (Text("Hacker").foregroundColor(HT.text) + Text("Tube").foregroundColor(HT.accent))
            .font(.system(size: size, weight: .bold))
            .tracking(-size * 0.04)
            .lineLimit(1)
            .fixedSize()
    }
}

/// The favicon: an orange rounded square with a white "H".
struct LogoMark: View {
    var size: CGFloat = 32
    var body: some View {
        RoundedRectangle(cornerRadius: size * 7 / 32, style: .continuous)
            .fill(HT.accent)
            .frame(width: size, height: size)
            .overlay(Text("H").font(.system(size: size * 22 / 32, weight: .bold)).foregroundColor(.white))
    }
}
