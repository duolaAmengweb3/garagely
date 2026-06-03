import Foundation
import SwiftData

enum Migrations {
    /// One-time, idempotent data migrations. Currently: fold the legacy single
    /// `photoData` on records/fuel into the new multi-attachment model.
    static func run(_ context: ModelContext) {
        let done = AppGroup.defaults?.bool(forKey: "migrated_photos_v1") ?? false
        guard !done else { return }

        if let records = try? context.fetch(FetchDescriptor<ServiceRecord>()) {
            for r in records where r.photoData != nil && r.attachments.isEmpty {
                let a = Attachment(kind: "photo", filename: "photo.jpg", data: r.photoData!)
                a.serviceRecord = r
                context.insert(a)
                r.photoData = nil
            }
        }
        if let fuel = try? context.fetch(FetchDescriptor<FuelEntry>()) {
            for f in fuel where f.photoData != nil && f.attachments.isEmpty {
                let a = Attachment(kind: "photo", filename: "photo.jpg", data: f.photoData!)
                a.fuelEntry = f
                context.insert(a)
                f.photoData = nil
            }
        }
        try? context.save()
        AppGroup.defaults?.set(true, forKey: "migrated_photos_v1")
    }
}
