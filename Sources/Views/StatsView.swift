import SwiftUI
import SwiftData
import Charts

struct StatsView: View {
    @Query private var vehicles: [Vehicle]
    @EnvironmentObject private var purchases: PurchaseManager
    @State private var period = 1   // 0=6M, 1=1Y, 2=All
    @State private var showPaywall = false
    @State private var showExport = false

    private var liveVehicles: [Vehicle] { vehicles.filter { !$0.isArchived } }
    private var allRecords: [ServiceRecord] { liveVehicles.flatMap(\.records) }
    private var allFuel: [FuelEntry] { liveVehicles.flatMap(\.fuelEntries) }
    private var allExpenses: [Expense] { liveVehicles.flatMap(\.expenses) }

    private var cutoff: Date? {
        let cal = Calendar.current
        switch period {
        case 0: return cal.date(byAdding: .month, value: -6, to: Date())
        case 1: return cal.date(byAdding: .year, value: -1, to: Date())
        default: return nil
        }
    }

    private func inWindow(_ d: Date) -> Bool { cutoff == nil || d >= cutoff! }

    private var totalSpend: Double {
        allRecords.filter { inWindow($0.date) }.reduce(0) { $0 + $1.cost }
        + allFuel.filter { inWindow($0.date) }.reduce(0) { $0 + $1.cost }
        + allExpenses.filter { inWindow($0.date) }.reduce(0) { $0 + $1.amount }
    }

    struct Cat: Identifiable { let id = UUID(); let label: String; let total: Double; let tint: Color; let symbol: String }

    private var breakdown: [Cat] {
        var rows: [Cat] = []
        let gas = allFuel.filter { inWindow($0.date) && !$0.isElectric }.reduce(0) { $0 + $1.cost }
        let elec = allFuel.filter { inWindow($0.date) && $0.isElectric }.reduce(0) { $0 + $1.cost }
        if gas > 0 { rows.append(Cat(label: "Fuel", total: gas, tint: Theme.brand, symbol: "fuelpump.fill")) }
        if elec > 0 { rows.append(Cat(label: "Charging", total: elec, tint: Theme.blue, symbol: "bolt.fill")) }
        let svc = Dictionary(grouping: allRecords.filter { inWindow($0.date) }) { $0.kind }.mapValues { $0.reduce(0) { $0 + $1.cost } }
        for (k, v) in svc where v > 0 { rows.append(Cat(label: k.label, total: v, tint: k.tint, symbol: k.symbol)) }
        let exp = Dictionary(grouping: allExpenses.filter { inWindow($0.date) }) { $0.category }.mapValues { $0.reduce(0) { $0 + $1.amount } }
        for (c, v) in exp where v > 0 { rows.append(Cat(label: c.label, total: v, tint: c.tint, symbol: c.symbol)) }
        return rows.sorted { $0.total > $1.total }
    }

    private var monthly: [(month: Date, total: Double)] {
        let cal = Calendar.current
        func bucket(_ d: Date) -> Date { cal.date(from: cal.dateComponents([.year, .month], from: d))! }
        var dict: [Date: Double] = [:]
        for r in allRecords where inWindow(r.date) { dict[bucket(r.date), default: 0] += r.cost }
        for f in allFuel where inWindow(f.date) { dict[bucket(f.date), default: 0] += f.cost }
        for e in allExpenses where inWindow(e.date) { dict[bucket(e.date), default: 0] += e.amount }
        return dict.map { ($0.key, $0.value) }.sorted { $0.month < $1.month }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Picker("", selection: $period) {
                        Text("6M").tag(0); Text("1Y").tag(1); Text("All").tag(2)
                    }.pickerStyle(.segmented)

                    // Hero
                    VStack(alignment: .leading, spacing: 6) {
                        Text("TOTAL COST OF OWNERSHIP").appFont(11, weight: .bold).tracking(0.5).foregroundStyle(Theme.ink3)
                        Text(totalSpend.currency)
                            .appFont(44, weight: .bold, design: .rounded).monospacedDigit()
                            .foregroundStyle(Theme.ink)
                        Text("fuel · charging · service · expenses").appFont(13, weight: .medium).foregroundStyle(Theme.ink2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card(padding: 18, radius: 22)

                    // Trend
                    if !monthly.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: "Monthly spend")
                            Chart(monthly, id: \.month) { m in
                                BarMark(x: .value("Month", m.month, unit: .month), y: .value("Spend", m.total))
                                    .foregroundStyle(Theme.brand.gradient)
                                    .cornerRadius(5)
                            }
                            .frame(height: 150)
                            .chartXAxis { AxisMarks(values: .stride(by: .month)) { _ in AxisValueLabel(format: .dateTime.month(.narrow)) } }
                        }
                        .card(padding: 16, radius: 22)
                    }

                    // Breakdown
                    if !breakdown.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            SectionHeader(title: "By category")
                            ForEach(breakdown.prefix(8)) { item in
                                let frac = totalSpend > 0 ? item.total / totalSpend : 0
                                VStack(spacing: 6) {
                                    HStack(spacing: 10) {
                                        Image(systemName: item.symbol).appFont(13, weight: .bold).foregroundStyle(item.tint).frame(width: 24)
                                        Text(item.label).appFont(14, weight: .semibold).foregroundStyle(Theme.ink)
                                        Spacer()
                                        Text(item.total.currency).appFont(14, weight: .semibold).monospacedDigit().foregroundStyle(Theme.ink)
                                    }
                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            Capsule().fill(Theme.line).frame(height: 6)
                                            Capsule().fill(item.tint).frame(width: max(6, geo.size.width * frac), height: 6)
                                        }
                                    }.frame(height: 6)
                                }
                            }
                        }
                        .card(padding: 16, radius: 22)
                    }

                    if purchases.isPro {
                        proAnalytics
                    } else {
                        Button { showPaywall = true } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "lock.fill").appFont(16, weight: .bold).foregroundStyle(Theme.brand)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Cost-per-mile & export").appFont(15, weight: .semibold).foregroundStyle(Theme.ink)
                                    Text("Unlock with Garagely Pro").appFont(13, weight: .medium).foregroundStyle(Theme.ink2)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").appFont(13, weight: .bold).foregroundStyle(Theme.ink3)
                            }
                            .card(padding: 16, radius: 20)
                        }.buttonStyle(.plain)
                    }

                    Color.clear.frame(height: 80)
                }
                .padding(.horizontal, 18).padding(.top, 4)
            }
            .screenBackground()
            .navigationTitle("Stats")
            .toolbar {
                if purchases.isPro && !liveVehicles.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showExport = true } label: { Image(systemName: "square.and.arrow.up") }
                            .foregroundStyle(Theme.brand)
                    }
                }
            }
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .sheet(isPresented: $showExport) { ExportSheet(vehicles: liveVehicles) }
        }
    }

    private var proAnalytics: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Cost per \(liveVehicles.first?.unit ?? "mi")")
            ForEach(liveVehicles) { v in
                HStack(spacing: 12) {
                    Image(systemName: "car.fill").foregroundStyle(v.accent).frame(width: 24)
                    Text(v.name).appFont(14, weight: .semibold).foregroundStyle(Theme.ink)
                    Spacer()
                    Text(costPerDistance(v)).appFont(14, weight: .semibold).monospacedDigit().foregroundStyle(Theme.ink)
                }
                if let eco = v.averageEconomy {
                    HStack(spacing: 12) {
                        Image(systemName: "fuelpump.fill").foregroundStyle(Theme.blue).frame(width: 24)
                        Text("Economy").appFont(13, weight: .medium).foregroundStyle(Theme.ink2)
                        Spacer()
                        Text(String(format: "%.1f %@", eco, v.economyUnit)).appFont(13, weight: .semibold).foregroundStyle(Theme.blue)
                    }
                }
            }
        }
        .card(padding: 16, radius: 22)
    }

    private func costPerDistance(_ v: Vehicle) -> String {
        let mileages = (v.records.map(\.mileage) + v.fuelEntries.map(\.mileage)).filter { $0 > 0 }
        guard let lo = mileages.min(), let hi = mileages.max(), hi > lo else { return "—" }
        let perMile = v.totalSpend / Double(hi - lo)
        return String(format: "$%.2f/%@", perMile, v.unit)
    }
}
