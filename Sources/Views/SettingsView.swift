import SwiftUI
import SwiftData
import StoreKit

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.requestReview) private var requestReview
    @EnvironmentObject private var purchases: PurchaseManager
    @EnvironmentObject private var notifications: NotificationManager
    @Query private var vehicles: [Vehicle]

    @AppStorage(AppSettingsKeys.iCloudEnabled, store: AppGroup.defaults) private var iCloudEnabled = false

    @State private var showPaywall = false
    @State private var showExport = false
    @State private var showIcons = false
    @State private var showTemplates = false
    @State private var notifEnabled = false
    @State private var showRelaunchNote = false

    private let supportEmail = "xxhhuan2022@163.com"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    proBanner
                    preferences
                    proTools
                    dataGroup
                    aboutGroup
                    Text("Garagely 1.0 · On-device · No account")
                        .appFont(12, weight: .medium).foregroundStyle(Theme.ink3).padding(.top, 8)
                    Color.clear.frame(height: 40)
                }
                .padding(.horizontal, 18).padding(.top, 4)
            }
            .screenBackground()
            .navigationTitle("Settings")
            .navigationDestination(isPresented: $showIcons) { AltIconsView() }
            .navigationDestination(isPresented: $showTemplates) { TemplatesView() }
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .sheet(isPresented: $showExport) { ExportSheet(vehicles: vehicles) }
            .alert("Relaunch to apply", isPresented: $showRelaunchNote) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(iCloudEnabled ? "Quit and reopen Garagely to start syncing your garage with iCloud."
                                   : "iCloud sync will stop the next time you open Garagely.")
            }
            .task { await notifications.refreshAuthorization(); notifEnabled = notifications.authorized }
        }
    }

    // MARK: Pro banner

    private var proBanner: some View {
        Button { showPaywall = true } label: {
            HStack(spacing: 14) {
                Image(systemName: purchases.isPro ? "checkmark.seal.fill" : "wrench.and.screwdriver.fill")
                    .appFont(20, weight: .bold).foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(purchases.isPro ? Theme.green : Theme.brand, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(purchases.isPro ? "Garagely Pro" : "Get Garagely Pro")
                        .appFont(16, weight: .bold).foregroundStyle(Theme.ink)
                    Text(purchases.isPro ? "All features unlocked — thank you!" : "Unlimited vehicles, analytics, export & more")
                        .appFont(13, weight: .medium).foregroundStyle(Theme.ink2)
                }
                Spacer()
                if !purchases.isPro {
                    Image(systemName: "chevron.right").appFont(13, weight: .bold).foregroundStyle(Theme.ink3)
                }
            }
            .card(padding: 14, radius: 20)
        }.buttonStyle(.plain)
    }

    // MARK: Preferences

    private var preferences: some View {
        groupCard("PREFERENCES") {
            Button { gated { showIcons = true } } label: {
                row("paintbrush.fill", "App Icon", trailing: purchases.isPro ? nil : "Pro", chevron: true)
            }.buttonStyle(.plain)
            divider
            Toggle(isOn: Binding(
                get: { notifEnabled },
                set: { newValue in
                    notifEnabled = newValue
                    if newValue {
                        Task {
                            let granted = await notifications.requestAuthorization()
                            notifEnabled = granted
                            GarageSync.refresh(context, notifications: notifications)
                        }
                    }
                })) { rowLabel("bell.fill", "Notifications") }
                .tint(Theme.brand).padding(14)
        }
    }

    // MARK: Pro tools

    private var proTools: some View {
        groupCard("PRO TOOLS") {
            Button { gated { showTemplates = true } } label: {
                row("square.stack.3d.up.fill", "Service Templates", trailing: purchases.isPro ? nil : "Pro", chevron: true)
            }.buttonStyle(.plain)
            divider
            if purchases.isPro {
                Toggle(isOn: Binding(
                    get: { iCloudEnabled },
                    set: { iCloudEnabled = $0; showRelaunchNote = true })) {
                    rowLabel("icloud.fill", "iCloud Sync")
                }.tint(Theme.brand).padding(14)
            } else {
                Button { showPaywall = true } label: {
                    row("icloud.fill", "iCloud Sync", trailing: "Pro", chevron: true)
                }.buttonStyle(.plain)
            }
        }
    }

    // MARK: Data

    private var dataGroup: some View {
        groupCard("DATA") {
            Button { gated { showExport = true } } label: {
                row("square.and.arrow.up.fill", "Export records", trailing: purchases.isPro ? nil : "Pro", chevron: true)
            }.buttonStyle(.plain)
        }
    }

    // MARK: About

    private var aboutGroup: some View {
        groupCard("ABOUT") {
            Button { requestReview() } label: { row("star.fill", "Rate Garagely", chevron: true) }.buttonStyle(.plain)
            divider
            NavigationLink { PrivacyView() } label: { row("hand.raised.fill", "Privacy", trailing: "No account", chevron: true) }
            divider
            Link(destination: URL(string: "mailto:\(supportEmail)?subject=Garagely%20Support")!) {
                row("envelope.fill", "Contact Support", chevron: true)
            }
        }
    }

    // MARK: gating

    private func gated(_ action: () -> Void) {
        if purchases.isPro { action() } else { showPaywall = true }
    }

    // MARK: building blocks

    private func groupCard<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).appFont(11, weight: .bold).tracking(0.5).foregroundStyle(Theme.ink3).padding(.leading, 4)
            VStack(spacing: 0) { content() }.card(padding: 0, radius: 18)
        }
    }
    private var divider: some View { Divider().overlay(Theme.line).padding(.leading, 52) }

    private func rowLabel(_ icon: String, _ title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).appFont(15, weight: .semibold).foregroundStyle(Theme.brand).frame(width: 26)
            Text(title).appFont(15, weight: .medium).foregroundStyle(Theme.ink)
        }
    }
    private func row(_ icon: String, _ title: String, trailing: String? = nil, chevron: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).appFont(15, weight: .semibold).foregroundStyle(Theme.brand).frame(width: 26)
            Text(title).appFont(15, weight: .medium).foregroundStyle(Theme.ink)
            Spacer()
            if let trailing { Text(trailing).appFont(14, weight: .semibold).foregroundStyle(trailing == "Pro" ? Theme.brand : Theme.ink2) }
            if chevron { Image(systemName: "chevron.right").appFont(12, weight: .bold).foregroundStyle(Theme.ink3) }
        }
        .padding(14)
    }
}

// MARK: - Export picker

struct ExportSheet: View {
    @Environment(\.dismiss) private var dismiss
    let vehicles: [Vehicle]
    @State private var shareURL: URL?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(vehicles) { v in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 10) {
                                Image(systemName: "car.fill").foregroundStyle(v.accent)
                                Text(v.name).appFont(16, weight: .semibold).foregroundStyle(Theme.ink)
                                Spacer()
                                Text("\(v.records.count + v.fuelEntries.count) records").appFont(13, weight: .medium).foregroundStyle(Theme.ink2)
                            }
                            HStack(spacing: 12) {
                                exportButton("CSV", "tablecells") { shareURL = ExportManager.csv(for: v) }
                                exportButton("PDF", "doc.richtext") { shareURL = ExportManager.pdf(for: v) }
                            }
                        }
                        .card(padding: 16, radius: 18)
                    }
                    Color.clear.frame(height: 20)
                }
                .padding(18)
            }
            .background(Theme.paper)
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() }.foregroundStyle(Theme.ink2) } }
            .sheet(item: $shareURL) { url in ShareSheet(items: [url]) }
        }
    }

    private func exportButton(_ label: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon).appFont(15, weight: .semibold)
                Text(label).appFont(15, weight: .semibold)
            }
            .foregroundStyle(Theme.brand).frame(maxWidth: .infinity).padding(.vertical, 13)
            .background(Theme.brandSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }.buttonStyle(.plain)
    }
}

extension URL: @retroactive Identifiable { public var id: String { absoluteString } }
