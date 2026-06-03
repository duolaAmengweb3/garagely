import AppIntents

// "Hey Siri, what's my next service in Garagely?"
struct NextServiceIntent: AppIntent {
    static var title: LocalizedStringResource = "Next Service"
    static var description = IntentDescription("Check what service is due next across your garage.")
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let snapshot = GarageSnapshot.load(), let top = snapshot.vehicles.first else {
            return .result(dialog: "Your garage is empty. Add a vehicle in Garagely to start tracking service.")
        }
        if top.statusRaw == 3 || top.nextTitle == nil {
            return .result(dialog: "Everything in your garage is up to date.")
        }
        let title = top.nextTitle ?? "Service"
        let when = top.nextHeadline ?? ""
        let verb = top.statusRaw == 2 ? "overdue" : "due"
        return .result(dialog: "\(top.name): \(title) is \(verb) \(when).")
    }
}

struct GaragelyShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: NextServiceIntent(),
            phrases: [
                "What's my next service in \(.applicationName)",
                "Check \(.applicationName)",
                "What's due in \(.applicationName)"
            ],
            shortTitle: "Next Service",
            systemImageName: "wrench.and.screwdriver.fill"
        )
    }
}
