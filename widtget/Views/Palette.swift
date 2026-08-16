import SwiftUI
import WidgetKit

enum WidtgetPalette {
    static let background = Color(red: 0.035, green: 0.047, blue: 0.063)
    static let surface = Color(red: 0.075, green: 0.094, blue: 0.118)
    static let raisedSurface = Color(red: 0.092, green: 0.115, blue: 0.143)
    static let border = Color.white.opacity(0.075)
    static let primaryText = Color(red: 0.93, green: 0.95, blue: 0.97)
    static let secondaryText = Color(red: 0.52, green: 0.57, blue: 0.63)
    static let green = Color(red: 0.22, green: 0.80, blue: 0.46)
    static let coral = Color(red: 0.95, green: 0.38, blue: 0.40)
    static let neutral = Color(red: 0.13, green: 0.16, blue: 0.20)
}

struct SurfaceModifier: ViewModifier {
    @Environment(\.widgetRenderingMode) private var renderingMode

    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(renderingMode == .fullColor ? WidtgetPalette.surface : Color.clear)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        renderingMode == .fullColor
                            ? WidtgetPalette.border
                            : Color.primary.opacity(0.14),
                        lineWidth: 1
                    )
            }
    }
}

extension View {
    func widtgetSurface(cornerRadius: CGFloat = 10) -> some View {
        modifier(SurfaceModifier(cornerRadius: cornerRadius))
    }
}
