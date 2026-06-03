import Foundation
import WidgetKit

enum SnapshotWriter {
    /// Write the current garage state for the widget and reload timelines.
    static func write(vehicles: [Vehicle]) {
        let snaps: [VehicleSnapshot] = vehicles.map { v in
            let due = v.nextDue
            let statusRaw: Int
            switch due?.info.status {
            case .overdue: statusRaw = 2
            case .dueSoon: statusRaw = 1
            case .healthy: statusRaw = 0
            case nil:      statusRaw = 3
            }
            let detail: String?
            if let m = due?.reminder.dueMileage { detail = "at \(m.milesGrouped) \(v.unit)" }
            else if let d = due?.reminder.dueDate { detail = d.shortLabel }
            else { detail = nil }

            return VehicleSnapshot(
                id: v.id, name: v.name, colorHex: v.colorHex,
                currentMileage: v.currentMileage, unit: v.unit,
                nextTitle: due?.reminder.title, nextDetail: detail,
                nextHeadline: due?.info.headline, statusRaw: statusRaw,
                sortKey: due?.info.sortKey ?? .greatestFiniteMagnitude)
        }
        .sorted { $0.sortKey < $1.sortKey }

        GarageSnapshot(vehicles: snaps, generatedAt: Date()).save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
