import SwiftUI

enum DS {
    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
    }

    enum Radius {
        static let md: CGFloat = 12
        static let lg: CGFloat = 18
    }

    enum Colors {
        static let bg = Color(nsColor: .windowBackgroundColor)
        static let panel = Color.white.opacity(0.05)
        static let border = Color.white.opacity(0.12)
        static let laneA = Color.white
        static let laneB = Color(red: 0.64, green: 0.84, blue: 1.0)
        static let success = Color.green.opacity(0.85)
        static let warning = Color.orange.opacity(0.9)
    }
}

struct GlassCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(DS.Spacing.md)
            .background(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .stroke(DS.Colors.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
    }
}

extension View {
    func glassCard() -> some View {
        modifier(GlassCard())
    }
}
