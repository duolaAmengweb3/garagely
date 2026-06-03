import SwiftUI
import SwiftData

@main
struct GaragelyApp: App {
    let container: ModelContainer
    @StateObject private var purchases = PurchaseManager()
    @StateObject private var icons = IconManager()
    @StateObject private var notifications = NotificationManager.shared

    init() {
        // CloudKit-ready schema: every attribute has a default and relationships
        // are optional, so the same store works locally or with iCloud (Pro).
        container = ContainerFactory.make()
        // Demo data only when capturing screenshots; real users start with onboarding.
        if ProcessInfo.processInfo.environment["SHOT"] != nil {
            SeedData.populateIfNeeded(container.mainContext)
        }
        if ProcessInfo.processInfo.environment["SELFTEST"] != nil {
            SelfTest.run()
        }
        Self.configureAppearance()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(purchases)
                .environmentObject(icons)
                .environmentObject(notifications)
                .tint(Theme.brand)
                // Support Dynamic Type, but cap the extreme accessibility sizes
                // so the tuned Workshop Ledger layout never breaks.
                .dynamicTypeSize(.xSmall ... .accessibility1)
                .task {
                    Migrations.run(container.mainContext)
                    await notifications.refreshAuthorization()
                    let vehicles = (try? container.mainContext.fetch(FetchDescriptor<Vehicle>())) ?? []
                    SnapshotWriter.write(vehicles: vehicles)
                    await notifications.sync(vehicles: vehicles)
                }
        }
        .modelContainer(container)
    }

    private static func configureAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Theme.surface)
        appearance.shadowColor = UIColor(Theme.line)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance

        let navigation = UINavigationBarAppearance()
        navigation.configureWithTransparentBackground()
        navigation.backgroundColor = .clear
        navigation.shadowColor = .clear
        navigation.titleTextAttributes = [.foregroundColor: UIColor(Theme.ink)]
        navigation.largeTitleTextAttributes = [.foregroundColor: UIColor(Theme.ink)]
        UINavigationBar.appearance().standardAppearance = navigation
        UINavigationBar.appearance().scrollEdgeAppearance = navigation
        UINavigationBar.appearance().compactAppearance = navigation
        UINavigationBar.appearance().tintColor = UIColor(Theme.brand)
    }
}

// Central place to refresh widget snapshot + notifications after any data mutation.
@MainActor
enum GarageSync {
    static func refresh(_ context: ModelContext, notifications: NotificationManager) {
        let vehicles = (try? context.fetch(FetchDescriptor<Vehicle>())) ?? []
        SnapshotWriter.write(vehicles: vehicles)
        Task { await notifications.sync(vehicles: vehicles) }
    }
}
