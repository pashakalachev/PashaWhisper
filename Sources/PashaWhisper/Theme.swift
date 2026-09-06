import SwiftUI

enum Theme {
    static let paper = Color(red: 0.95, green: 0.92, blue: 0.87)
    static let ink = Color(red: 0.13, green: 0.14, blue: 0.12)
    static let red = Color(red: 0.77, green: 0.18, blue: 0.14)
    static let muted = Color(red: 0.39, green: 0.39, blue: 0.35)
    static let sheet = Color(red: 0.98, green: 0.96, blue: 0.92)
    static func mono(_ size: CGFloat = 11) -> Font { .system(size: size, weight: .medium, design: .monospaced) }
    static func title(_ size: CGFloat = 35) -> Font { .system(size: size, weight: .black, design: .default).width(.condensed) }
}

struct BlockButton: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var primary = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(Theme.mono(12)).fontWeight(.bold)
            .padding(.horizontal, 16).padding(.vertical, 12)
            .foregroundStyle(primary ? Theme.paper : Theme.ink)
            .background(primary ? Theme.red : Theme.paper)
            .overlay(Rectangle().stroke(Theme.ink, lineWidth: 2))
            .offset(x: configuration.isPressed ? 1 : 0, y: configuration.isPressed ? 1 : 0)
            .opacity(!isEnabled ? 0.4 : configuration.isPressed ? 0.8 : 1)
    }
}

struct SmallLabel: View {
    let text: String
    var body: some View { Text(text.uppercased()).font(Theme.mono(10)).tracking(1.6).foregroundStyle(Theme.muted) }
}

struct CatMark: View {
    var color: Color = Theme.ink
    var eyeColor: Color = Theme.paper
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            Path { p in
                p.move(to: CGPoint(x: w * 0.08, y: h * 0.1))
                for point in [CGPoint(x: w * 0.32, y: h * 0.3), CGPoint(x: w * 0.68, y: h * 0.3),
                            CGPoint(x: w * 0.92, y: h * 0.1), CGPoint(x: w * 0.92, y: h * 0.7),
                            CGPoint(x: w * 0.7, y: h * 0.94), CGPoint(x: w * 0.3, y: h * 0.94), CGPoint(x: w * 0.08, y: h * 0.7)] { p.addLine(to: point) }
                p.closeSubpath()
            }.fill(color)
            HStack(spacing: w * 0.20) {
                Circle().fill(eyeColor).frame(width: w * 0.12)
                Circle().fill(eyeColor).frame(width: w * 0.12)
            }.position(x: w * 0.5, y: h * 0.54)
            Rectangle().fill(Theme.red).frame(width: w * 0.1, height: h * 0.08).rotationEffect(.degrees(45))
                .position(x: w * 0.5, y: h * 0.72)
        }.accessibilityHidden(true)
    }
}

struct Rule: View {
    var body: some View { Rectangle().fill(Theme.ink).frame(height: 2) }
}

struct PosterCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.sheet).overlay(Rectangle().stroke(Theme.ink, lineWidth: 2))
    }
}
