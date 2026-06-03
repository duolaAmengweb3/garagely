import Foundation

// Shared between the app and the widget extension.

enum AppGroup {
    static let id = "group.com.duolaameng.garagely"
    static var defaults: UserDefaults? { UserDefaults(suiteName: id) }
}

enum ProductIDs {
    static let pro = "com.duolaameng.garagely.pro"
}

// Lightweight snapshot the app writes on every save; the widget reads it.
// Keeps the widget free of the SwiftData stack.

struct VehicleSnapshot: Codable, Identifiable {
    var id: UUID
    var name: String
    var colorHex: UInt
    var currentMileage: Int
    var unit: String
    var nextTitle: String?
    var nextDetail: String?
    var nextHeadline: String?
    var statusRaw: Int          // 0 healthy, 1 dueSoon, 2 overdue, 3 none
    var sortKey: Double
}

struct GarageSnapshot: Codable {
    var vehicles: [VehicleSnapshot]
    var generatedAt: Date

    static let key = "garage_snapshot_v1"

    static func load() -> GarageSnapshot? {
        guard let data = AppGroup.defaults?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(GarageSnapshot.self, from: data)
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        AppGroup.defaults?.set(data, forKey: GarageSnapshot.key)
    }
}
