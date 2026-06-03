import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Query private var vehicles: [Vehicle]
    @State private var tab = 0

    // Screenshot harness hooks (driven by the SHOT env var).
    @State private var shotAdd = false
    @State private var shotPaywall = false
    @State private var shotIcons = false
    @State private var shotExport = false
    @State private var shotTemplates = false

    private static let shot = ProcessInfo.processInfo.environment["SHOT"]

    var body: some View {
        Group {
            if vehicles.isEmpty && Self.shot == nil {
                OnboardingView()
            } else {
                tabs
            }
        }
    }

    private var tabs: some View {
        TabView(selection: $tab) {
            GarageView().tabItem { Label("Garage", systemImage: "car.2.fill") }.tag(0)
            RemindersView().tabItem { Label("Reminders", systemImage: "bell.fill") }.tag(1)
            StatsView().tabItem { Label("Stats", systemImage: "chart.bar.fill") }.tag(2)
            SettingsView().tabItem { Label("Settings", systemImage: "gearshape.fill") }.tag(3)
        }
        .tint(Theme.brand)
        .sheet(isPresented: $shotAdd) { AddRecordView(vehicles: vehicles, preselected: vehicles.first) }
        .sheet(isPresented: $shotPaywall) { PaywallView() }
        .sheet(isPresented: $shotIcons) { NavigationStack { AltIconsView() } }
        .sheet(isPresented: $shotExport) { ExportSheet(vehicles: vehicles) }
        .sheet(isPresented: $shotTemplates) { NavigationStack { TemplatesView() } }
        .onAppear {
            switch Self.shot {
            case "reminders": tab = 1
            case "stats": tab = 2
            case "settings": tab = 3
            case "add": DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { shotAdd = true }
            case "paywall": DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { shotPaywall = true }
            case "icons": DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { shotIcons = true }
            case "export": DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { shotExport = true }
            case "templates": DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { shotTemplates = true }
            default: break
            }
        }
    }
}
