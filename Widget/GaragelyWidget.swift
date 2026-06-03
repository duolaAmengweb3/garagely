import WidgetKit
import SwiftUI

// MARK: - Palette (mirrors the app's Workshop Ledger tokens)

private enum W {
    static func c(_ hex: UInt) -> Color {
        Color(.sRGB, red: Double((hex >> 16) & 0xff)/255, green: Double((hex >> 8) & 0xff)/255, blue: Double(hex & 0xff)/255, opacity: 1)
    }
    static let brand = c(0xED5B22), green = c(0x2E9E6B), amber = c(0xE0A008), red = c(0xE5484D)
    static let ink = c(0x202321), ink2 = c(0x696B66), paper = c(0xF4F1EB), graphite = c(0x202724)
    static func status(_ raw: Int) -> Color {
        switch raw { case 2: return red; case 1: return amber; case 0: return green; default: return ink2 }
    }
    static func symbol(_ raw: Int) -> String {
        switch raw { case 2: return "exclamationmark.triangle.fill"; case 1: return "clock.fill"; case 0: return "checkmark.circle.fill"; default: return "checkmark.seal.fill" }
    }
}

// MARK: - Timeline

struct GarageEntry: TimelineEntry {
    let date: Date
    let snapshot: GarageSnapshot?
}

struct GarageProvider: TimelineProvider {
    func placeholder(in context: Context) -> GarageEntry {
        GarageEntry(date: Date(), snapshot: sample)
    }
    func getSnapshot(in context: Context, completion: @escaping (GarageEntry) -> Void) {
        completion(GarageEntry(date: Date(), snapshot: GarageSnapshot.load() ?? sample))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<GarageEntry>) -> Void) {
        let entry = GarageEntry(date: Date(), snapshot: GarageSnapshot.load())
        // Refresh a few times a day; the app also reloads on every data change.
        let next = Calendar.current.date(byAdding: .hour, value: 6, to: Date()) ?? Date().addingTimeInterval(21600)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private var sample: GarageSnapshot {
        GarageSnapshot(vehicles: [
            VehicleSnapshot(id: UUID(), name: "Honda Civic", colorHex: 0xED5B22, currentMileage: 42300, unit: "mi",
                            nextTitle: "Oil change", nextDetail: "at 46,480 mi", nextHeadline: "in 820 mi", statusRaw: 0, sortKey: 820)
        ], generatedAt: Date())
    }
}

// MARK: - Views

struct GaragelyWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: GarageEntry

    private var vehicles: [VehicleSnapshot] { entry.snapshot?.vehicles ?? [] }
    private var top: VehicleSnapshot? { vehicles.first }
    private var dueCount: Int { vehicles.filter { $0.statusRaw == 1 || $0.statusRaw == 2 }.count }

    var body: some View {
        switch family {
        case .accessoryCircular: circular
        case .accessoryInline:   inline
        case .accessoryRectangular: rectangular
        case .systemMedium:      medium
        default:                 small
        }
    }

    // Lock screen
    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 1) {
                Image(systemName: dueCount == 0 ? "checkmark.seal.fill" : "wrench.and.screwdriver.fill")
                    .font(.system(size: 15, weight: .bold))
                Text(dueCount == 0 ? "OK" : "\(dueCount)").font(.system(size: 13, weight: .bold)).monospacedDigit()
            }
        }
    }
    private var inline: some View {
        if let t = top, let title = t.nextTitle, t.statusRaw != 3 {
            Label("\(title) \(t.nextHeadline ?? "")", systemImage: "wrench.and.screwdriver.fill")
        } else {
            Label("All up to date", systemImage: "checkmark.seal.fill")
        }
    }
    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let t = top {
                Text(t.name).font(.system(size: 14, weight: .bold)).lineLimit(1)
                if let title = t.nextTitle, t.statusRaw != 3 {
                    Label { Text("\(title) · \(t.nextHeadline ?? "")").lineLimit(1) }
                        icon: { Image(systemName: W.symbol(t.statusRaw)) }
                        .font(.system(size: 12, weight: .medium))
                } else {
                    Label("All up to date", systemImage: "checkmark.seal.fill").font(.system(size: 12, weight: .medium))
                }
            } else {
                Text("Garagely").font(.system(size: 14, weight: .bold))
                Text("Add a vehicle").font(.system(size: 12))
            }
        }
    }

    // Home screen
    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "car.2.fill").font(.system(size: 13, weight: .bold)).foregroundStyle(W.brand)
                Spacer()
                if let t = top { Circle().fill(W.status(t.statusRaw)).frame(width: 9, height: 9) }
            }
            Spacer()
            if let t = top {
                Text(t.name).font(.system(size: 15, weight: .bold)).foregroundStyle(W.ink).lineLimit(1)
                if let title = t.nextTitle, t.statusRaw != 3 {
                    Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(W.ink2).lineLimit(1)
                    Text(t.nextHeadline ?? "").font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(W.status(t.statusRaw)).monospacedDigit().lineLimit(1)
                } else {
                    Text("All up to date").font(.system(size: 12, weight: .semibold)).foregroundStyle(W.green)
                }
            } else {
                Text("Garagely").font(.system(size: 15, weight: .bold)).foregroundStyle(W.ink)
                Text("Add a vehicle").font(.system(size: 12, weight: .medium)).foregroundStyle(W.ink2)
            }
            Spacer()
            if let t = top {
                Text("\(t.currentMileage.grouped) \(t.unit)").font(.system(size: 11, weight: .semibold)).foregroundStyle(W.ink2).monospacedDigit()
            }
        }
        .padding(14)
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "car.2.fill").font(.system(size: 13, weight: .bold)).foregroundStyle(W.brand)
                Text("Garage").font(.system(size: 14, weight: .bold)).foregroundStyle(W.ink)
                Spacer()
                Text(dueCount == 0 ? "All clear" : "\(dueCount) due")
                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(dueCount == 0 ? W.green : W.brand)
            }
            ForEach(vehicles.prefix(3)) { v in
                HStack(spacing: 10) {
                    Circle().fill(W.status(v.statusRaw)).frame(width: 8, height: 8)
                    Text(v.name).font(.system(size: 13, weight: .semibold)).foregroundStyle(W.ink).lineLimit(1)
                    Spacer()
                    if let title = v.nextTitle, v.statusRaw != 3 {
                        Text("\(title) · \(v.nextHeadline ?? "")")
                            .font(.system(size: 12, weight: .medium)).foregroundStyle(W.ink2).lineLimit(1)
                    } else {
                        Text("Up to date").font(.system(size: 12, weight: .medium)).foregroundStyle(W.green)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
    }
}

private extension Int {
    var grouped: String {
        let f = NumberFormatter(); f.numberStyle = .decimal
        return f.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

// MARK: - Widget

struct GaragelyWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "GaragelyWidget", provider: GarageProvider()) { entry in
            GaragelyWidgetEntryView(entry: entry)
                .containerBackground(W.paper, for: .widget)
        }
        .configurationDisplayName("Next Service")
        .description("See what's due next across your garage.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct GaragelyWidgetBundle: WidgetBundle {
    var body: some Widget { GaragelyWidget() }
}
