import SwiftUI
import SwiftData

struct ArchivedVehiclesView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var notifications: NotificationManager
    @Query private var vehicles: [Vehicle]

    private var archived: [Vehicle] { vehicles.filter { $0.isArchived }.sorted { $0.name < $1.name } }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if archived.isEmpty {
                    EmptyHint(symbol: "archivebox", text: "No archived vehicles", sub: "Vehicles you sell are kept here with all their records.").padding(.top, 40)
                } else {
                    ForEach(archived) { v in
                        VStack(spacing: 12) {
                            NavigationLink(value: v.id) {
                                HStack(spacing: 14) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 13, style: .continuous).fill(Theme.graphite).frame(width: 46, height: 46)
                                        Image(systemName: "car.fill").appFont(20, weight: .semibold).foregroundStyle(Theme.chalk)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(v.name).appFont(16, weight: .bold).foregroundStyle(Theme.ink)
                                        Text("\(v.subtitle) · \(v.records.count + v.fuelEntries.count + v.expenses.count) records").appFont(13, weight: .medium).foregroundStyle(Theme.ink2)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").appFont(13, weight: .bold).foregroundStyle(Theme.ink3)
                                }
                            }.buttonStyle(.plain)
                            Button { restore(v) } label: {
                                HStack(spacing: 6) { Image(systemName: "arrow.uturn.backward"); Text("Restore to Garage") }
                                    .appFont(14, weight: .semibold).foregroundStyle(Theme.brand)
                                    .frame(maxWidth: .infinity).padding(.vertical, 11)
                                    .background(Theme.brandSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }.buttonStyle(.plain)
                        }
                        .card(padding: 14, radius: 18)
                    }
                }
                Color.clear.frame(height: 40)
            }
            .padding(18)
        }
        .screenBackground()
        .navigationTitle("Archived")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func restore(_ v: Vehicle) {
        v.isArchived = false
        try? context.save()
        GarageSync.refresh(context, notifications: notifications)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
