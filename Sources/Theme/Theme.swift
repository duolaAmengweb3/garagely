import SwiftUI

// MARK: - Garagely design system
// "Workshop Ledger" — paper, graphite and safety orange.
// Solid surfaces only. Depth comes from contrast, hairlines and restrained shadows.

enum Theme {
    static let paper     = Color(hex: 0xF4F1EB)   // workshop ledger paper
    static let surface   = Color.white            // cards
    static let surface2  = Color(hex: 0xFBFAF7)   // inset fields
    static let ink       = Color(hex: 0x202321)   // graphite primary text
    static let ink2      = Color(hex: 0x696B66)   // secondary text
    static let ink3      = Color(hex: 0xA6A69E)   // tertiary text / icons
    static let line      = Color(hex: 0xE8E5DE)   // hairlines
    static let graphite  = Color(hex: 0x202724)   // workshop hero surface
    static let graphite2 = Color(hex: 0x303936)   // raised graphite surface
    static let chalk     = Color(hex: 0xF6F1E7)   // text on graphite
    static let chalk2    = Color(hex: 0xB7BDB7)   // muted text on graphite

    static let brand     = Color(hex: 0xED5B22)   // safety orange
    static let brandSoft = Color(hex: 0xFBE5D9)

    static let green     = Color(hex: 0x2E9E6B)   // healthy
    static let greenSoft = Color(hex: 0xE2F3EB)
    static let amber     = Color(hex: 0xE0A008)   // due soon
    static let amberSoft = Color(hex: 0xFAF0D4)
    static let red       = Color(hex: 0xE5484D)   // overdue
    static let redSoft   = Color(hex: 0xFBE3E3)
    static let blue      = Color(hex: 0x3B7DD8)   // fuel accent
    static let blueSoft  = Color(hex: 0xE5EEFA)
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(.sRGB,
                  red:   Double((hex >> 16) & 0xff) / 255,
                  green: Double((hex >> 8)  & 0xff) / 255,
                  blue:  Double( hex        & 0xff) / 255,
                  opacity: alpha)
    }
}

// MARK: - Reusable surface styling

extension View {
    /// Opaque card with gentle, layered shadow. The core surface of the app.
    func card(padding: CGFloat = 16, radius: CGFloat = 22) -> some View {
        self
            .padding(padding)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(Theme.line, lineWidth: 0.75)
            }
            .shadow(color: .black.opacity(0.045), radius: 14, x: 0, y: 8)
            .shadow(color: .black.opacity(0.025), radius: 1, x: 0, y: 1)
    }

    func screenBackground() -> some View {
        self.background(Theme.paper.ignoresSafeArea())
    }
}

// MARK: - Service health

enum ServiceStatus {
    case healthy, dueSoon, overdue

    var color: Color {
        switch self {
        case .healthy: return Theme.green
        case .dueSoon: return Theme.amber
        case .overdue: return Theme.red
        }
    }
    var soft: Color {
        switch self {
        case .healthy: return Theme.greenSoft
        case .dueSoon: return Theme.amberSoft
        case .overdue: return Theme.redSoft
        }
    }
}
