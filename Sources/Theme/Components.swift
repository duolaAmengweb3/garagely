import SwiftUI

// MARK: - Status pill (color + SF Symbol + text — never color alone, per a11y)

struct StatusPill: View {
    let status: ServiceStatus
    let text: String
    var compact: Bool = false

    private var symbol: String {
        switch status {
        case .healthy: return "checkmark.circle.fill"
        case .dueSoon: return "clock.fill"
        case .overdue: return "exclamationmark.triangle.fill"
        }
    }

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .appFont(compact ? 11 : 12, weight: .bold)
            Text(text)
                .appFont(compact ? 12 : 13, weight: .semibold)
                .monospacedDigit()
        }
        .foregroundStyle(status.color)
        .padding(.horizontal, compact ? 8 : 10)
        .padding(.vertical, compact ? 4 : 6)
        .background(status.soft, in: Capsule())
    }
}

// MARK: - Health ring (fraction healthy, tinted by worst state)

struct HealthRing: View {
    let fraction: Double          // 0...1 healthy
    let tint: Color
    var size: CGFloat = 52
    var line: CGFloat = 6
    var centerSymbol: String? = nil

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.line, lineWidth: line)
            Circle()
                .trim(from: 0, to: max(0.02, fraction))
                .stroke(tint, style: StrokeStyle(lineWidth: line, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if let s = centerSymbol {
                Image(systemName: s)
                    .font(.system(size: size * 0.34, weight: .bold))
                    .foregroundStyle(tint)
            }
        }
        .frame(width: size, height: size)
        .animation(.smooth, value: fraction)
    }
}

// MARK: - Category icon tile

struct KindIcon: View {
    let kind: RecordKind
    var size: CGFloat = 38

    var body: some View {
        Image(systemName: kind.symbol)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(kind.tint)
            .frame(width: size, height: size)
            .background(kind.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
    }
}

// MARK: - Section header

struct SectionHeader: View {
    let title: String
    var trailing: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .appFont(20, weight: .bold)
                .foregroundStyle(Theme.ink)
            Spacer()
            if let t = trailing {
                Text(t)
                    .appFont(14, weight: .semibold)
                    .foregroundStyle(Theme.ink2)
                    .monospacedDigit()
            }
        }
    }
}

// MARK: - Primary button (solid Service Orange)

struct PrimaryButton: View {
    let title: String
    var icon: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon).appFont(16, weight: .bold) }
                Text(title).appFont(17, weight: .semibold)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Theme.brand, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Big stat tile (bento)

struct StatTile: View {
    let label: String
    let value: String
    var caption: String? = nil
    var tint: Color = Theme.ink
    var symbol: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if let symbol {
                    Image(systemName: symbol).appFont(13, weight: .bold).foregroundStyle(tint)
                }
                Text(label.uppercased())
                    .appFont(11, weight: .bold)
                    .foregroundStyle(Theme.ink3)
                    .tracking(0.5)
            }
            Text(value)
                .appFont(26, weight: .bold, design: .rounded)
                .foregroundStyle(Theme.ink)
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            if let caption {
                Text(caption)
                    .appFont(12, weight: .medium)
                    .foregroundStyle(Theme.ink2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 16, radius: 20)
    }
}
