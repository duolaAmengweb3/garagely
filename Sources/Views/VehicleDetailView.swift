import SwiftUI
import SwiftData
import Charts

struct VehicleDetailView: View {
    @Bindable var vehicle: Vehicle
    @EnvironmentObject private var purchases: PurchaseManager
    @State private var segment = 0
    @State private var showAddMenu = false
    @State private var showAddRecord = false
    @State private var showAddExpense = false
    @State private var showEditVehicle = false
    @State private var editingRecord: ServiceRecord?
    @State private var editingFuel: FuelEntry?
    @State private var editingExpense: Expense?

    private var due: (reminder: Reminder, info: DueInfo)? { vehicle.nextDue }
    private var fuelTabTitle: String { vehicle.powertrain == .ev ? "Charging" : "Fuel" }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                Picker("", selection: $segment) {
                    Text("Timeline").tag(0)
                    Text(fuelTabTitle).tag(1)
                    Text("Costs").tag(2)
                    Text("Info").tag(3)
                }
                .pickerStyle(.segmented)

                switch segment {
                case 1: FuelSection(vehicle: vehicle) { editingFuel = $0 }
                case 2: CostsSection(vehicle: vehicle, isPro: purchases.isPro,
                                     onAddExpense: { showAddExpense = true },
                                     onEditExpense: { editingExpense = $0 })
                case 3: InfoSection(vehicle: vehicle)
                default: TimelineSection(vehicle: vehicle) { editingRecord = $0 }
                }
                Color.clear.frame(height: 80)
            }
            .padding(.horizontal, 18).padding(.top, 4)
        }
        .onAppear { if let t = Int(ProcessInfo.processInfo.environment["DETAILTAB"] ?? "") { segment = t } }
        .screenBackground()
        .navigationTitle(vehicle.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { showEditVehicle = true }.foregroundStyle(Theme.brand)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            Menu {
                Button { showAddRecord = true } label: { Label(vehicle.powertrain == .ev ? "Log Service or Charge" : "Log Service or Fuel", systemImage: "wrench.and.screwdriver.fill") }
                Button { showAddExpense = true } label: { Label("Log Expense", systemImage: "dollarsign.circle.fill") }
            } label: {
                Image(systemName: "plus").appFont(22, weight: .bold).foregroundStyle(.white)
                    .frame(width: 58, height: 58).background(Theme.brand, in: Circle())
                    .shadow(color: Theme.brand.opacity(0.4), radius: 14, x: 0, y: 8)
            }
            .padding(.trailing, 20).padding(.bottom, 20)
            .accessibilityLabel("Add")
        }
        .sheet(isPresented: $showAddRecord) { AddRecordView(vehicles: [vehicle], preselected: vehicle) }
        .sheet(isPresented: $showAddExpense) { ExpenseEditorView(vehicles: [vehicle], preselected: vehicle) }
        .sheet(isPresented: $showEditVehicle) { VehicleEditorView(editing: vehicle) }
        .sheet(item: $editingRecord) { rec in AddRecordView(vehicles: [vehicle], editingService: rec) }
        .sheet(item: $editingFuel) { f in AddRecordView(vehicles: [vehicle], editingFuel: f) }
        .sheet(item: $editingExpense) { e in ExpenseEditorView(vehicles: [vehicle], editing: e) }
    }

    private var header: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ODOMETER").appFont(11, weight: .bold).tracking(0.5).foregroundStyle(Theme.chalk2)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(vehicle.currentMileage.milesGrouped).appFont(40, weight: .bold, design: .rounded)
                            .monospacedDigit().foregroundStyle(Theme.chalk)
                        Text(vehicle.unit).appFont(16, weight: .semibold).foregroundStyle(Theme.chalk2)
                    }
                }
                Spacer()
                economyReadout
            }
            if let due {
                HStack(spacing: 12) {
                    KindIcon(kind: due.reminder.kind, size: 38)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Next: \(due.reminder.title)").appFont(15, weight: .semibold).foregroundStyle(Theme.chalk)
                        Text(due.reminder.dueMileage != nil ? "at \(due.reminder.dueMileage!.milesGrouped) \(vehicle.unit)"
                                                            : (due.reminder.dueDate?.shortLabel ?? "")).appFont(13, weight: .medium).foregroundStyle(Theme.chalk2)
                    }
                    Spacer()
                    StatusPill(status: due.info.status, text: due.info.headline, compact: true)
                }
                .padding(12).background(Theme.graphite2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.white.opacity(0.06), lineWidth: 1) }
            }
        }
        .padding(18).background(Theme.graphite, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(.white.opacity(0.06), lineWidth: 1) }
        .shadow(color: .black.opacity(0.12), radius: 18, x: 0, y: 10)
    }

    @ViewBuilder private var economyReadout: some View {
        HStack(spacing: 14) {
            if let eco = vehicle.averageEconomy {
                economyPill(vehicle.economyUnit, String(format: "%.1f", eco), Theme.brand)
            }
            if let ev = vehicle.electricEconomy {
                economyPill(vehicle.electricEconomyUnit, String(format: "%.1f", ev), Theme.blue)
            }
        }
    }
    private func economyPill(_ unit: String, _ value: String, _ tint: Color) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(unit).appFont(11, weight: .bold).tracking(0.5).foregroundStyle(Theme.chalk2)
            Text(value).appFont(26, weight: .bold, design: .rounded).monospacedDigit().foregroundStyle(tint)
        }
    }
}

// MARK: - Timeline

struct TimelineSection: View {
    let vehicle: Vehicle
    var onEdit: (ServiceRecord) -> Void = { _ in }

    private var grouped: [(month: String, records: [ServiceRecord], subtotal: Double)] {
        let sorted = vehicle.records.sorted { $0.date > $1.date }
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"
        let dict = Dictionary(grouping: sorted) { f.string(from: $0.date) }
        return dict.map { key, recs in (key, recs.sorted { $0.date > $1.date }, recs.reduce(0) { $0 + $1.cost }) }
            .sorted { ($0.records.first?.date ?? .distantPast) > ($1.records.first?.date ?? .distantPast) }
    }

    var body: some View {
        if vehicle.records.isEmpty {
            EmptyHint(symbol: "wrench.and.screwdriver", text: "No records yet", sub: "Tap + to log your first service.")
        } else {
            VStack(spacing: 18) {
                ForEach(grouped, id: \.month) { group in
                    VStack(spacing: 0) {
                        HStack {
                            Text(group.month).appFont(13, weight: .bold).foregroundStyle(Theme.ink2)
                            Spacer()
                            Text(group.subtotal.currency(code: vehicle.currencyCode)).appFont(13, weight: .semibold).foregroundStyle(Theme.ink3).monospacedDigit()
                        }
                        .padding(.horizontal, 4).padding(.bottom, 8)
                        VStack(spacing: 0) {
                            ForEach(Array(group.records.enumerated()), id: \.element.id) { idx, rec in
                                Button { onEdit(rec) } label: { RecordRow(record: rec, vehicle: vehicle) }.buttonStyle(.plain)
                                if idx < group.records.count - 1 { Divider().overlay(Theme.line).padding(.leading, 52) }
                            }
                        }
                        .card(padding: 0, radius: 20)
                    }
                }
            }
        }
    }
}

struct RecordRow: View {
    let record: ServiceRecord
    let vehicle: Vehicle
    var body: some View {
        HStack(spacing: 12) {
            KindIcon(kind: record.kind, size: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text(record.title).appFont(15, weight: .semibold).foregroundStyle(Theme.ink)
                HStack(spacing: 5) {
                    Text("\(record.mileage.milesGrouped) \(vehicle.unit) · \(record.date.monthDay)").appFont(13, weight: .medium).foregroundStyle(Theme.ink2).monospacedDigit()
                    if !record.attachments.isEmpty {
                        Image(systemName: "paperclip").appFont(11, weight: .semibold).foregroundStyle(Theme.ink3)
                    }
                }
            }
            Spacer()
            if record.cost > 0 { Text(record.cost.currency(code: vehicle.currencyCode)).appFont(15, weight: .semibold).foregroundStyle(Theme.ink).monospacedDigit() }
        }
        .padding(14)
    }
}

// MARK: - Fuel / Charge

struct FuelSection: View {
    let vehicle: Vehicle
    var onEdit: (FuelEntry) -> Void = { _ in }

    private var fills: [FuelEntry] { vehicle.fuelEntries.sorted { $0.date > $1.date } }

    // Single-tank stats (best / worst / avg) for liquid fills.
    private var tankStats: (best: Double, worst: Double, avgDist: Double)? {
        let gas = vehicle.fuelEntries.filter { $0.isFull && !$0.isElectric }.sorted { $0.mileage < $1.mileage }
        guard gas.count >= 2 else { return nil }
        var economies: [Double] = [], dists: [Int] = []
        for i in 1..<gas.count {
            let d = gas[i].mileage - gas[i-1].mileage
            if gas[i].volume > 0 { economies.append(Double(d) / gas[i].volume) }
            dists.append(d)
        }
        guard let best = economies.max(), let worst = economies.min(), !dists.isEmpty else { return nil }
        return (best, worst, Double(dists.reduce(0,+)) / Double(dists.count))
    }

    var body: some View {
        if fills.isEmpty {
            EmptyHint(symbol: vehicle.powertrain == .ev ? "bolt.car" : "fuelpump",
                      text: vehicle.powertrain == .ev ? "No charges yet" : "No fill-ups yet",
                      sub: "Log \(vehicle.powertrain == .ev ? "a charge" : "fuel") to track efficiency.")
        } else {
            VStack(spacing: 16) {
                if let s = tankStats {
                    HStack(spacing: 12) {
                        StatTile(label: "Best", value: String(format: "%.1f", s.best), caption: vehicle.economyUnit, tint: Theme.green, symbol: "arrow.up")
                        StatTile(label: "Worst", value: String(format: "%.1f", s.worst), caption: vehicle.economyUnit, tint: Theme.amber, symbol: "arrow.down")
                        StatTile(label: "Per tank", value: "\(Int(s.avgDist).milesGrouped)", caption: vehicle.unit, symbol: "gauge.with.dots.needle.50percent")
                    }
                }
                if vehicle.averageEconomy != nil || vehicle.electricEconomy != nil {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader(title: "Spend per fill")
                        Chart(fills.reversed()) { e in
                            LineMark(x: .value("Date", e.date), y: .value("Cost", e.cost))
                                .foregroundStyle(e.isElectric ? Theme.blue : Theme.brand).interpolationMethod(.catmullRom)
                            AreaMark(x: .value("Date", e.date), y: .value("Cost", e.cost))
                                .foregroundStyle(.linearGradient(colors: [Theme.brand.opacity(0.15), .clear], startPoint: .top, endPoint: .bottom)).interpolationMethod(.catmullRom)
                        }
                        .frame(height: 120).chartYAxis { AxisMarks(position: .leading) }
                    }
                    .card(padding: 16, radius: 20)
                }
                VStack(spacing: 0) {
                    ForEach(Array(fills.enumerated()), id: \.element.id) { idx, e in
                        Button { onEdit(e) } label: { fuelRow(e) }.buttonStyle(.plain)
                        if idx < fills.count - 1 { Divider().overlay(Theme.line).padding(.leading, 52) }
                    }
                }
                .card(padding: 0, radius: 20)
            }
        }
    }

    private func fuelRow(_ e: FuelEntry) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous).fill((e.isElectric ? Theme.blue : Theme.brand).opacity(0.12)).frame(width: 38, height: 38)
                Image(systemName: e.isElectric ? "bolt.fill" : "fuelpump.fill").appFont(15, weight: .semibold).foregroundStyle(e.isElectric ? Theme.blue : Theme.brand)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: "%.1f %@", e.volume, e.isElectric ? "kWh" : vehicle.fuelUnit)).appFont(15, weight: .semibold).foregroundStyle(Theme.ink)
                Text("\(e.mileage.milesGrouped) \(vehicle.unit) · \(e.date.monthDay)\(e.isFull ? "" : " · partial")\(e.isElectric && e.chargeLocationRaw != nil ? " · \(ChargeLocation(rawValue: e.chargeLocationRaw!)?.label ?? "")" : "")").appFont(13, weight: .medium).foregroundStyle(Theme.ink2).monospacedDigit()
            }
            Spacer()
            Text(e.cost.currency(code: vehicle.currencyCode)).appFont(15, weight: .semibold).foregroundStyle(Theme.ink).monospacedDigit()
        }
        .padding(14)
    }
}

// MARK: - Costs (TCO)

struct CostsSection: View {
    let vehicle: Vehicle
    let isPro: Bool
    var onAddExpense: () -> Void = {}
    var onEditExpense: (Expense) -> Void = { _ in }

    private struct Cat: Identifiable { let id = UUID(); let label: String; let total: Double; let tint: Color; let symbol: String }

    private var breakdown: [Cat] {
        var rows: [Cat] = []
        let gas = vehicle.fuelEntries.filter { !$0.isElectric }.reduce(0) { $0 + $1.cost }
        let elec = vehicle.fuelEntries.filter { $0.isElectric }.reduce(0) { $0 + $1.cost }
        if gas > 0 { rows.append(Cat(label: "Fuel", total: gas, tint: Theme.brand, symbol: "fuelpump.fill")) }
        if elec > 0 { rows.append(Cat(label: "Charging", total: elec, tint: Theme.blue, symbol: "bolt.fill")) }
        let svc = Dictionary(grouping: vehicle.records) { $0.kind }.mapValues { $0.reduce(0) { $0 + $1.cost } }
        for (k, v) in svc where v > 0 { rows.append(Cat(label: k.label, total: v, tint: k.tint, symbol: k.symbol)) }
        let exp = Dictionary(grouping: vehicle.expenses) { $0.category }.mapValues { $0.reduce(0) { $0 + $1.amount } }
        for (c, v) in exp where v > 0 { rows.append(Cat(label: c.label, total: v, tint: c.tint, symbol: c.symbol)) }
        return rows.sorted { $0.total > $1.total }
    }

    private var costPerMile: Double? {
        let m = (vehicle.records.map(\.mileage) + vehicle.fuelEntries.map(\.mileage) + vehicle.expenses.compactMap(\.mileage)).filter { $0 > 0 }
        guard let lo = m.min(), let hi = m.max(), hi > lo else { return nil }
        return vehicle.totalSpend / Double(hi - lo)
    }

    private var expenses: [Expense] { vehicle.expenses.sorted { $0.date > $1.date } }

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                StatTile(label: "Total cost", value: vehicle.totalSpend.currency(code: vehicle.currencyCode), tint: Theme.brand, symbol: "creditcard.fill")
                if isPro, let cpm = costPerMile {
                    StatTile(label: "Per \(vehicle.unit)", value: cpm.currency(code: vehicle.currencyCode), caption: "all-in", symbol: "gauge.with.dots.needle.50percent")
                } else {
                    StatTile(label: "Records", value: "\(vehicle.records.count + vehicle.fuelEntries.count + vehicle.expenses.count)", caption: "all time", symbol: "list.bullet")
                }
            }

            if !breakdown.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Where it goes")
                    ForEach(breakdown) { c in
                        let frac = vehicle.totalSpend > 0 ? c.total / vehicle.totalSpend : 0
                        VStack(spacing: 6) {
                            HStack(spacing: 10) {
                                Image(systemName: c.symbol).appFont(13, weight: .bold).foregroundStyle(c.tint).frame(width: 22)
                                Text(c.label).appFont(14, weight: .semibold).foregroundStyle(Theme.ink)
                                Spacer()
                                Text(c.total.currency(code: vehicle.currencyCode)).appFont(14, weight: .semibold).monospacedDigit().foregroundStyle(Theme.ink)
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Theme.line).frame(height: 6)
                                    Capsule().fill(c.tint).frame(width: max(6, geo.size.width * frac), height: 6)
                                }
                            }.frame(height: 6)
                        }
                    }
                }
                .card(padding: 16, radius: 20)
            }

            // Expenses list
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionHeader(title: "Expenses")
                    Button(action: onAddExpense) { Image(systemName: "plus.circle.fill").appFont(20).foregroundStyle(Theme.brand) }
                }
                if expenses.isEmpty {
                    Text("No expenses yet — track insurance, registration, tolls and more.").appFont(13, weight: .medium).foregroundStyle(Theme.ink2)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(expenses.enumerated()), id: \.element.id) { idx, e in
                            Button { onEditExpense(e) } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: e.category.symbol).appFont(15, weight: .semibold).foregroundStyle(e.category.tint).frame(width: 38, height: 38)
                                        .background(e.category.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(e.category.label).appFont(15, weight: .semibold).foregroundStyle(Theme.ink)
                                        Text(e.date.monthDay + (e.recurrence != .none ? " · \(e.recurrence.label)" : "")).appFont(13, weight: .medium).foregroundStyle(Theme.ink2)
                                    }
                                    Spacer()
                                    Text(e.amount.currency(code: vehicle.currencyCode)).appFont(15, weight: .semibold).foregroundStyle(Theme.ink).monospacedDigit()
                                }
                                .padding(.vertical, 10)
                            }.buttonStyle(.plain)
                            if idx < expenses.count - 1 { Divider().overlay(Theme.line).padding(.leading, 50) }
                        }
                    }
                }
            }
            .card(padding: 16, radius: 20)
        }
    }
}

// MARK: - Empty hint

struct EmptyHint: View {
    let symbol: String, text: String, sub: String
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol).appFont(32, weight: .medium).foregroundStyle(Theme.ink3)
            Text(text).appFont(16, weight: .semibold).foregroundStyle(Theme.ink)
            Text(sub).appFont(13, weight: .medium).foregroundStyle(Theme.ink2).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 40).card(padding: 16, radius: 20)
    }
}
