import Foundation
import UserNotifications
import SwiftData

@MainActor
final class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    @Published var authorized = false

    func refreshAuthorization() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorized = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            authorized = granted
            return granted
        } catch {
            return false
        }
    }

    /// Re-schedule all date-based reminders across every vehicle.
    func sync(vehicles: [Vehicle]) async {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        guard authorized else { return }

        let cal = Calendar.current
        for vehicle in vehicles {
            for reminder in vehicle.reminders {
                // The engine projects mileage-based reminders into a date so they
                // can fire too, and subtracts the lead time.
                guard let fire = reminder.fireDate(in: vehicle) else { continue }
                let content = UNMutableNotificationContent()
                content.title = vehicle.name
                content.body = "\(reminder.title) is due soon"
                content.sound = .default

                var comps = cal.dateComponents([.year, .month, .day], from: fire)
                comps.hour = 9
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                let request = UNNotificationRequest(identifier: reminder.notificationID, content: content, trigger: trigger)
                try? await center.add(request)
            }
        }
    }
}
