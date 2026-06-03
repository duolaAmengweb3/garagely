import SwiftUI
import SwiftData

struct GarageView: View {
    @Query private var vehicles: [Vehicle]
    @EnvironmentObject private var purchases: PurchaseManager
    @State private var path = NavigationPath()
    @State private var showAddVehicle = false
    @State private var showAddRecord = false
    @State private var showAddExpense = false
    @State private var showPaywall = false

    // Active (non-archived) vehicles, worst-urgency first.
    private var sorted: [Vehicle] {
        vehicles.filter { !$0.isArchived }.sorted { a, b in
            (a.nextDue?.info.sortKey ?? .greatestFiniteMagnitude)
            < (b.nextDue?.info.sortKey ?? .greatestFiniteMagnitude)
        }
    }

    private var archivedCount: Int { vehicles.filter { $0.isArchived }.count }

    private var attentionCount: Int {
        sorted.filter {
            if let s = $0.nextDue?.info.status { return s != .healthy }
            return false
        }.count
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 18) {
                    summary
                    HStack {
                        Text("YOUR VEHICLES")
                            .appFont(11, weight: .bold)
                            .tracking(1.1)
                            .foregroundStyle(Theme.ink3)
                        Spacer()
                        Text("\(sorted.count) TOTAL")
                            .appFont(11, weight: .bold)
                            .tracking(0.7)
                            .foregroundStyle(Theme.ink3)
                    }
                    .padding(.horizontal, 2)
                    ForEach(sorted) { vehicle in
                        NavigationLink(value: vehicle.id) {
                            VehicleCard(vehicle: vehicle)
                        }
                        .buttonStyle(.plain)
                    }
                    if archivedCount > 0 {
                        NavigationLink { ArchivedVehiclesView() } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "archivebox.fill").appFont(14, weight: .semibold).foregroundStyle(Theme.ink3)
                                Text("Archived").appFont(14, weight: .semibold).foregroundStyle(Theme.ink2)
                                Spacer()
                                Text("\(archivedCount)").appFont(14, weight: .semibold).foregroundStyle(Theme.ink3)
                                Image(systemName: "chevron.right").appFont(12, weight: .bold).foregroundStyle(Theme.ink3)
                            }
                            .padding(14).card(padding: 0, radius: 16)
                        }.buttonStyle(.plain)
                    }
                    Color.clear.frame(height: 80)
                }
                .padding(.horizontal, 18)
                .padding(.top, 4)
            }
            .screenBackground()
            .navigationTitle("Garage")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { addVehicle() } label: { Label("Add Vehicle", systemImage: "car.fill") }
                        if !sorted.isEmpty {
                            Button { showAddRecord = true } label: { Label("Log Service or Fuel", systemImage: "wrench.and.screwdriver.fill") }
                            Button { showAddExpense = true } label: { Label("Log Expense", systemImage: "dollarsign.circle.fill") }
                        }
                    } label: {
                        Image(systemName: "plus")
                            .appFont(15, weight: .bold).foregroundStyle(.white)
                            .frame(width: 34, height: 34).background(Theme.brand, in: Circle())
                    }
                    .accessibilityLabel("Add")
                }
            }
            .navigationDestination(for: UUID.self) { id in
                if let v = vehicles.first(where: { $0.id == id }) {
                    VehicleDetailView(vehicle: v)
                }
            }
            .sheet(isPresented: $showAddVehicle) { VehicleEditorView() }
            .sheet(isPresented: $showAddRecord) { AddRecordView(vehicles: sorted, preselected: sorted.first) }
            .sheet(isPresented: $showAddExpense) { ExpenseEditorView(vehicles: sorted, preselected: sorted.first) }
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .onAppear {
                let shot = ProcessInfo.processInfo.environment["SHOT"]
                if shot == "detail", let first = sorted.first, path.isEmpty {
                    path.append(first.id)
                } else if shot == "detailev", let ev = sorted.first(where: { $0.powertrain == .ev }), path.isEmpty {
                    path.append(ev.id)
                }
            }
        }
    }

    private func addVehicle() {
        // Free tier: one vehicle. Adding a second is the natural paywall moment.
        if !purchases.isPro && sorted.count >= ProLimits.freeVehicleLimit {
            showPaywall = true
        } else {
            showAddVehicle = true
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("GARAGE STATUS")
                        .appFont(11, weight: .bold)
                        .tracking(1.2)
                        .foregroundStyle(Theme.chalk2)
                    Text(attentionCount == 0 ? "All clear" : "\(attentionCount) service item\(attentionCount > 1 ? "s" : "") due")
                        .appFont(25, weight: .semibold, design: .rounded)
                        .foregroundStyle(Theme.chalk)
                }
                Spacer()
                Image(systemName: attentionCount == 0 ? "checkmark.seal.fill" : "wrench.and.screwdriver.fill")
                    .appFont(20, weight: .bold)
                    .foregroundStyle(attentionCount == 0 ? Theme.green : Theme.brand)
                    .frame(width: 46, height: 46)
                    .background(Theme.graphite2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            HStack(spacing: 0) {
                summaryMetric(value: "\(vehicles.count)", label: "VEHICLES")
                divider
                summaryMetric(value: "\(attentionCount)", label: "NEEDS CARE")
                divider
                summaryMetric(value: attentionCount == 0 ? "READY" : "CHECK", label: "NEXT STEP")
            }
        }
        .padding(18)
        .background(Theme.graphite, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.06), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.12), radius: 18, x: 0, y: 10)
    }

    private func summaryMetric(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .appFont(17, weight: .bold, design: .rounded)
                .foregroundStyle(Theme.chalk)
                .monospacedDigit()
            Text(label)
                .appFont(9, weight: .bold)
                .tracking(0.7)
                .foregroundStyle(Theme.chalk2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var divider: some View {
        Rectangle()
            .fill(.white.opacity(0.12))
            .frame(width: 1, height: 32)
            .padding(.horizontal, 12)
    }
}

// MARK: - Vehicle card

struct VehicleCard: View {
    let vehicle: Vehicle

    private var due: (reminder: Reminder, info: DueInfo)? { vehicle.nextDue }

    private var healthFraction: Double {
        let total = vehicle.reminders.count
        guard total > 0 else { return 1 }
        let healthy = vehicle.reminders.filter {
            $0.liveDue(in: vehicle).status == .healthy
        }.count
        return Double(healthy) / Double(total)
    }

    private var ringTint: Color { due?.info.status.color ?? Theme.green }

    var body: some View {
        VStack(spacing: 0) {
            // Top: identity + health ring
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(Theme.graphite)
                        .frame(width: 54, height: 54)
                    Image(systemName: "car.fill")
                        .appFont(22, weight: .semibold)
                        .foregroundStyle(Theme.chalk)
                    Rectangle()
                        .fill(vehicle.accent)
                        .frame(width: 28, height: 3)
                        .offset(y: 27)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(vehicle.name)
                        .appFont(19, weight: .bold)
                        .foregroundStyle(Theme.ink)
                    Text(vehicle.subtitle)
                        .appFont(13, weight: .medium)
                        .foregroundStyle(Theme.ink2)
                }
                Spacer()
                HealthRing(fraction: healthFraction, tint: ringTint, size: 46, line: 5,
                           centerSymbol: due?.info.status == .overdue ? "exclamationmark" : nil)
            }

            HStack(spacing: 6) {
                Text("NEXT SERVICE")
                    .appFont(10, weight: .bold)
                    .tracking(0.8)
                    .foregroundStyle(Theme.ink3)
                Rectangle().fill(Theme.line).frame(height: 1)
            }
            .padding(.vertical, 14)

            // Headline: the single most urgent thing
            HStack(spacing: 12) {
                if let due {
                    KindIcon(kind: due.reminder.kind, size: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(due.reminder.title)
                            .appFont(15, weight: .semibold)
                            .foregroundStyle(Theme.ink)
                        Text(headlineSubtitle(due))
                            .appFont(13, weight: .medium)
                            .foregroundStyle(Theme.ink2)
                    }
                    Spacer()
                    StatusPill(status: due.info.status, text: due.info.headline, compact: true)
                } else {
                    Image(systemName: "checkmark.seal.fill")
                        .appFont(18, weight: .bold)
                        .foregroundStyle(Theme.green)
                    Text("All up to date")
                        .appFont(15, weight: .semibold)
                        .foregroundStyle(Theme.ink)
                    Spacer()
                }
            }

            // Footer: odometer
            HStack(spacing: 6) {
                Image(systemName: "gauge.with.dots.needle.50percent")
                    .appFont(12, weight: .bold)
                    .foregroundStyle(Theme.brand)
                Text("\(vehicle.currentMileage.milesGrouped) \(vehicle.unit)")
                    .appFont(13, weight: .semibold)
                    .foregroundStyle(Theme.ink)
                    .monospacedDigit()
                Spacer()
                Text("\(vehicle.records.count) records")
                    .appFont(12, weight: .medium)
                    .foregroundStyle(Theme.ink3)
            }
            .padding(.top, 14)
        }
        .card(padding: 18, radius: 24)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(a11yLabel)
        .accessibilityHint("Opens vehicle details")
    }

    private var a11yLabel: String {
        var parts = ["\(vehicle.name), \(vehicle.currentMileage.milesGrouped) \(vehicle.unit)"]
        if let due {
            parts.append("\(due.reminder.title) \(due.info.headline)")
        } else {
            parts.append("all up to date")
        }
        return parts.joined(separator: ", ")
    }

    private func headlineSubtitle(_ due: (reminder: Reminder, info: DueInfo)) -> String {
        if let m = due.reminder.dueMileage { return "at \(m.milesGrouped) \(vehicle.unit)" }
        if let d = due.reminder.dueDate { return d.shortLabel }
        return "Next service"
    }
}
