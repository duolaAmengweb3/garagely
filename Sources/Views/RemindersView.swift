import SwiftUI
import SwiftData

struct RemindersView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var notifications: NotificationManager
    @Query private var vehicles: [Vehicle]

    @State private var showAdd = false
    @State private var editing: Reminder?

    private struct Item: Identifiable {
        let id = UUID()
        let vehicle: Vehicle
        let reminder: Reminder
        let info: DueInfo
    }

    private var items: [Item] {
        vehicles.flatMap { v in
            v.reminders.filter { $0.isEnabled }.map { Item(vehicle: v, reminder: $0, info: $0.liveDue(in: v)) }
        }
        .sorted { $0.info.sortKey < $1.info.sortKey }
    }

    private func group(_ s: ServiceStatus) -> [Item] { items.filter { $0.info.status == s } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if items.isEmpty {
                        EmptyHint(symbol: "bell", text: "No reminders yet",
                                  sub: vehicles.isEmpty ? "Add a vehicle to get started." : "Tap + to schedule a service.")
                            .padding(.top, 40)
                    } else {
                        section("Overdue", .overdue)
                        section("Due soon", .dueSoon)
                        section("Upcoming", .healthy)
                    }
                    Color.clear.frame(height: 80)
                }
                .padding(.horizontal, 18).padding(.top, 4)
            }
            .screenBackground()
            .navigationTitle("Reminders")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: {
                        Image(systemName: "plus")
                            .appFont(15, weight: .bold).foregroundStyle(.white)
                            .frame(width: 34, height: 34).background(Theme.brand, in: Circle())
                    }
                    .disabled(vehicles.isEmpty)
                    .accessibilityLabel("Add reminder")
                }
            }
            .sheet(isPresented: $showAdd) { ReminderEditorView(vehicles: vehicles) }
            .sheet(item: $editing) { rem in ReminderEditorView(vehicles: vehicles, editing: rem) }
        }
    }

    @ViewBuilder
    private func section(_ title: String, _ status: ServiceStatus) -> some View {
        let rows = group(status)
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Circle().fill(status.color).frame(width: 8, height: 8)
                    Text(title).appFont(18, weight: .bold).foregroundStyle(Theme.ink)
                    Text("\(rows.count)").appFont(14, weight: .semibold).foregroundStyle(Theme.ink3)
                    Spacer()
                }
                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { idx, item in
                        Button { editing = item.reminder } label: {
                            HStack(spacing: 12) {
                                KindIcon(kind: item.reminder.kind, size: 38)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.reminder.title)
                                        .appFont(15, weight: .semibold).foregroundStyle(Theme.ink)
                                    HStack(spacing: 5) {
                                        Image(systemName: "car.fill").appFont(10).foregroundStyle(item.vehicle.accent)
                                        Text(item.vehicle.name)
                                            .appFont(13, weight: .medium).foregroundStyle(Theme.ink2)
                                    }
                                }
                                Spacer()
                                StatusPill(status: item.info.status, text: item.info.headline, compact: true)
                            }
                            .padding(14)
                        }
                        .buttonStyle(.plain)
                        if idx < rows.count - 1 { Divider().overlay(Theme.line).padding(.leading, 52) }
                    }
                }
                .card(padding: 0, radius: 20)
            }
        }
    }
}
