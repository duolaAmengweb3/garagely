import SwiftData
import Foundation

enum AppSettingsKeys {
    static let proCached = "pro_cached"
    static let iCloudEnabled = "icloud_enabled"
}

enum ContainerFactory {
    static let allModels: [any PersistentModel.Type] =
        [Vehicle.self, ServiceRecord.self, FuelEntry.self, Reminder.self,
         ServiceTemplate.self, Expense.self, Attachment.self, EVReading.self]

    /// iCloud sync turns on only for a Pro user who enabled it. `.automatic`
    /// gracefully falls back to a local store when the iCloud entitlement is
    /// absent (e.g. the simulator), so Debug builds keep working and testing.
    static func make() -> ModelContainer {
        let d = AppGroup.defaults
        let pro = d?.bool(forKey: AppSettingsKeys.proCached) ?? false
        let cloudOn = d?.bool(forKey: AppSettingsKeys.iCloudEnabled) ?? false
        let useCloud = pro && cloudOn

        let schema = Schema(allModels)
        let config = ModelConfiguration(schema: schema, cloudKitDatabase: useCloud ? .automatic : .none)
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            // Never block launch — fall back to a clean local store.
            let local = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
            return try! ModelContainer(for: schema, configurations: local)
        }
    }
}
