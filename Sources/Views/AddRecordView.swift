import SwiftUI
import SwiftData
import PhotosUI

struct AddRecordView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var notifications: NotificationManager

    let vehicles: [Vehicle]
    var editingService: ServiceRecord?
    var editingFuel: FuelEntry?

    @State private var vehicle: Vehicle?
    @State private var mode = 0            // 0 = service, 1 = fuel/charge

    // shared
    @State private var date = Date()
    @State private var mileageText = ""
    @State private var costText = ""
    @State private var notes = ""
    @State private var photos: [Data] = []
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showCamera = false
    // service
    @State private var kind: RecordKind = .oil
    @State private var titleText = ""
    @State private var alsoRemind = false
    @State private var remindIntervalText = "5000"
    // fuel / charge
    @State private var volumeText = ""
    @State private var pricePerText = ""
    @State private var isFull = true
    @State private var energy: EnergyKind = .gas
    @State private var chargeLocation: ChargeLocation = .home
    @State private var showDelete = false
    // completion loop
    @State private var showCompletion = false
    @State private var completionMatches: [Reminder] = []
    @State private var savedMileage = 0
    @State private var savedDate = Date()

    init(vehicles: [Vehicle], preselected: Vehicle? = nil,
         editingService: ServiceRecord? = nil, editingFuel: FuelEntry? = nil) {
        self.vehicles = vehicles
        self.editingService = editingService
        self.editingFuel = editingFuel
        _vehicle = State(initialValue: editingService?.vehicle ?? editingFuel?.vehicle ?? preselected ?? vehicles.first)
        _mode = State(initialValue: editingFuel != nil ? 1 : 0)
    }

    private var isEditing: Bool { editingService != nil || editingFuel != nil }
    private let serviceKinds: [RecordKind] = [.oil, .tires, .brakes, .service, .battery, .inspection, .repair, .custom]
    private var isElectric: Bool { energy == .electric }
    private var volumeUnit: String { isElectric ? "kWh" : (vehicle?.fuelUnit ?? "gal") }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    if !isEditing { modePicker }
                    if vehicles.count > 1 && !isEditing { vehiclePicker }
                    if mode == 0 { serviceForm } else { fuelForm }
                    commonFields
                    photoField
                    if mode == 0 && !isEditing { contextualReminder }
                    if isEditing {
                        Button(role: .destructive) { showDelete = true } label: {
                            Text("Delete").appFont(16, weight: .semibold)
                                .frame(maxWidth: .infinity).padding(.vertical, 15).foregroundStyle(Theme.red)
                                .background(Theme.redSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                    Color.clear.frame(height: 16)
                }
                .padding(18)
            }
            .background(Theme.paper)
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.foregroundStyle(Theme.ink2) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.appFont(17, weight: .semibold)
                        .foregroundStyle(canSave ? Theme.brand : Theme.ink3).disabled(!canSave)
                }
            }
            .onAppear(perform: load)
            .onChange(of: pickerItems) { _, items in
                Task {
                    for item in items {
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let img = UIImage(data: data), let jpeg = img.jpegForStorage() { photos.append(jpeg) }
                    }
                    pickerItems = []
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { img in if let d = img.jpegForStorage() { photos.append(d) } }.ignoresSafeArea()
            }
            .confirmationDialog("Delete this record?", isPresented: $showDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) { delete() }
            }
            .alert("Reminder complete?", isPresented: $showCompletion) {
                Button("Schedule next") { completeMatches() }
                Button("Not now", role: .cancel) { finalize() }
            } message: {
                Text("You logged \(titleText). Mark \(completionMatches.count > 1 ? "these reminders" : "the \"\(completionMatches.first?.title ?? "")\" reminder") done and schedule the next one?")
            }
        }
        .presentationDragIndicator(.visible)
    }

    private var navTitle: String {
        if isEditing { return mode == 0 ? "Edit Service" : (isElectric ? "Edit Charge" : "Edit Fuel") }
        return mode == 0 ? "Log Service" : (isElectric ? "Log Charge" : "Log Fuel")
    }

    // MARK: subviews

    private var modePicker: some View {
        Picker("", selection: $mode) {
            Label("Service", systemImage: "wrench.and.screwdriver.fill").tag(0)
            Label(fuelTabLabel, systemImage: fuelTabIcon).tag(1)
        }.pickerStyle(.segmented)
    }
    private var fuelTabLabel: String {
        guard let p = vehicle?.powertrain else { return "Fuel" }
        return p == .ev ? "Charge" : "Fuel"
    }
    private var fuelTabIcon: String {
        (vehicle?.powertrain == .ev) ? "bolt.fill" : "fuelpump.fill"
    }

    private var vehiclePicker: some View {
        Menu {
            ForEach(vehicles) { v in Button(v.name) { vehicle = v; mileageText = "\(v.currentMileage)"; configureEnergy() } }
        } label: {
            HStack {
                Image(systemName: "car.fill").foregroundStyle(vehicle?.accent ?? Theme.ink2)
                Text(vehicle?.name ?? "Select vehicle").foregroundStyle(Theme.ink).fontWeight(.semibold)
                Spacer()
                Image(systemName: "chevron.up.chevron.down").appFont(12, weight: .bold).foregroundStyle(Theme.ink3)
            }
            .padding(14).background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.line, lineWidth: 0.75))
        }
    }

    private var serviceForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("TYPE").appFont(11, weight: .bold).tracking(0.5).foregroundStyle(Theme.ink3)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                ForEach(serviceKinds) { k in
                    Button {
                        UISelectionFeedbackGenerator().selectionChanged()
                        kind = k
                        if titleText.isEmpty || serviceKinds.map(\.label).contains(titleText) { titleText = k.label }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: k.symbol).appFont(18, weight: .semibold).foregroundStyle(kind == k ? .white : k.tint)
                            Text(k.label).appFont(10, weight: .semibold).lineLimit(1).minimumScaleFactor(0.7).foregroundStyle(kind == k ? .white : Theme.ink2)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(kind == k ? Theme.brand : Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.line, lineWidth: kind == k ? 0 : 0.75))
                    }.buttonStyle(.plain)
                }
            }
            field("Title") { TextField(kind.label, text: $titleText).textInputAutocapitalization(.words) }
        }
    }

    private var fuelForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            if vehicle?.powertrain == .phev {
                Picker("", selection: $energy) {
                    Label("Fuel", systemImage: "fuelpump.fill").tag(EnergyKind.gas)
                    Label("Charge", systemImage: "bolt.fill").tag(EnergyKind.electric)
                }.pickerStyle(.segmented)
            }
            HStack(spacing: 12) {
                field("\(isElectric ? "Energy" : "Volume") (\(volumeUnit))") {
                    TextField("0.0", text: $volumeText).keyboardType(.decimalPad).onChange(of: volumeText) { _, _ in recomputeFuelCost() }
                }
                field("Price / \(volumeUnit)") {
                    TextField("0.00", text: $pricePerText).keyboardType(.decimalPad).onChange(of: pricePerText) { _, _ in recomputeFuelCost() }
                }
            }
            if isElectric {
                VStack(alignment: .leading, spacing: 6) {
                    Text("LOCATION").appFont(10, weight: .bold).tracking(0.5).foregroundStyle(Theme.ink3)
                    Picker("", selection: $chargeLocation) {
                        ForEach(ChargeLocation.allCases) { Text($0.label).tag($0) }
                    }.pickerStyle(.segmented)
                }
            } else {
                Toggle(isOn: $isFull) { Text("Full tank").appFont(15, weight: .semibold).foregroundStyle(Theme.ink) }
                    .tint(Theme.brand)
                    .padding(14).background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.line, lineWidth: 0.75))
            }
            if isElectric {
                Toggle(isOn: $isFull) { Text("Full charge").appFont(15, weight: .semibold).foregroundStyle(Theme.ink) }
                    .tint(Theme.brand)
                    .padding(14).background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.line, lineWidth: 0.75))
            }
            if let eco = livePreviewEconomy {
                HStack(spacing: 6) {
                    Image(systemName: isElectric ? "bolt.fill" : "gauge.with.dots.needle.67percent").foregroundStyle(Theme.blue)
                    Text(String(format: "≈ %.1f %@ since last %@", eco, economyUnitForEntry, isElectric ? "charge" : "fill-up"))
                        .appFont(13, weight: .semibold).foregroundStyle(Theme.blue)
                }
            }
        }
    }

    private var commonFields: some View {
        VStack(spacing: 14) {
            field("Odometer (\(vehicle?.unit ?? "mi"))") {
                TextField("0", text: $mileageText).keyboardType(.numberPad).monospacedDigit()
            }
            field("Cost") {
                HStack(spacing: 2) {
                    Text(Currencies.symbol(vehicle?.currencyCode ?? "USD")).foregroundStyle(Theme.ink2)
                    TextField("0.00", text: $costText).keyboardType(.decimalPad).monospacedDigit()
                }
            }
            field("Date") { DatePicker("", selection: $date, displayedComponents: .date).labelsHidden() }
            field("Notes") { TextField("Optional", text: $notes, axis: .vertical).lineLimit(1...3) }
        }
    }

    private var photoField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PHOTOS / RECEIPTS").appFont(11, weight: .bold).tracking(0.5).foregroundStyle(Theme.ink3)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(photos.enumerated()), id: \.offset) { idx, d in
                        if let img = UIImage(data: d) {
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: img).resizable().scaledToFill().frame(width: 92, height: 92).clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                Button { photos.remove(at: idx) } label: {
                                    Image(systemName: "xmark.circle.fill").appFont(20).foregroundStyle(.white, .black.opacity(0.45))
                                }.padding(3)
                            }
                        }
                    }
                    PhotosPicker(selection: $pickerItems, maxSelectionCount: 8, matching: .images) {
                        addTile("photo.on.rectangle")
                    }
                    Button { showCamera = true } label: { addTile("camera.fill") }
                }
            }
        }
    }

    private func addTile(_ icon: String) -> some View {
        Image(systemName: icon).appFont(20, weight: .semibold).foregroundStyle(Theme.ink3)
            .frame(width: 92, height: 92)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.line, lineWidth: 0.75))
    }

    private var contextualReminder: some View {
        VStack(spacing: 12) {
            Toggle(isOn: $alsoRemind) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Remind me next time").appFont(15, weight: .semibold).foregroundStyle(Theme.ink)
                    Text("Schedule the next \(kind.label.lowercased())").appFont(12, weight: .medium).foregroundStyle(Theme.ink2)
                }
            }.tint(Theme.brand)
            if alsoRemind {
                field("Every (\(vehicle?.unit ?? "mi"))") {
                    TextField("5000", text: $remindIntervalText).keyboardType(.numberPad).monospacedDigit()
                }
            }
        }
        .padding(16).background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.line, lineWidth: 0.75))
    }

    private func field<C: View>(_ label: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased()).appFont(11, weight: .bold).tracking(0.5).foregroundStyle(Theme.ink3)
            content()
                .appFont(17, weight: .medium).foregroundStyle(Theme.ink)
                .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.line, lineWidth: 0.75))
        }
    }

    // MARK: logic

    private var canSave: Bool {
        guard vehicle != nil, Int(mileageText) != nil else { return false }
        if mode == 1 { return Double(volumeText) != nil }
        return !titleText.isEmpty
    }

    private var economyUnitForEntry: String {
        isElectric ? (vehicle?.electricEconomyUnit ?? "mi/kWh") : (vehicle?.economyUnit ?? "MPG")
    }

    private var livePreviewEconomy: Double? {
        guard let v = vehicle, let m = Int(mileageText), let vol = Double(volumeText), vol > 0,
              let last = v.fuelEntries.filter({ $0.isFull && $0.isElectric == isElectric && $0.id != editingFuel?.id }).map(\.mileage).max(),
              m > last else { return nil }
        return Double(m - last) / vol
    }

    private func configureEnergy() {
        switch vehicle?.powertrain {
        case .ev: energy = .electric
        default: energy = .gas
        }
    }

    private func load() {
        if let r = editingService {
            kind = r.kind; titleText = r.title; date = r.date; mileageText = "\(r.mileage)"
            costText = r.cost == 0 ? "" : String(format: "%.2f", r.cost); notes = r.notes
            photos = r.attachments.filter { !$0.isDocument }.map(\.data)
        } else if let f = editingFuel {
            date = f.date; mileageText = "\(f.mileage)"; costText = String(format: "%.2f", f.cost)
            volumeText = String(format: "%.1f", f.volume); isFull = f.isFull; notes = f.notes
            energy = f.energyKind
            if let loc = f.chargeLocationRaw { chargeLocation = ChargeLocation(rawValue: loc) ?? .home }
            photos = f.attachments.filter { !$0.isDocument }.map(\.data)
        } else {
            if let v = vehicle { mileageText = "\(v.currentMileage)" }
            titleText = kind.label
            configureEnergy()
        }
    }

    private func recomputeFuelCost() {
        if let vol = Double(volumeText), let price = Double(pricePerText) {
            costText = String(format: "%.2f", vol * price)
        }
    }

    private func attach(to record: ServiceRecord) {
        for a in record.attachments where !a.isDocument { context.delete(a) }
        for d in photos { let a = Attachment(kind: "photo", filename: "photo.jpg", data: d); a.serviceRecord = record; context.insert(a) }
    }
    private func attach(to entry: FuelEntry) {
        for a in entry.attachments where !a.isDocument { context.delete(a) }
        for d in photos { let a = Attachment(kind: "photo", filename: "photo.jpg", data: d); a.fuelEntry = entry; context.insert(a) }
    }

    private func save() {
        guard let v = vehicle, let mileage = Int(mileageText) else { return }
        let cost = Double(costText) ?? 0

        if mode == 0 {
            let rec: ServiceRecord
            if let r = editingService {
                r.kindRaw = kind.rawValue; r.title = titleText; r.date = date; r.mileage = mileage
                r.cost = cost; r.notes = notes; rec = r
            } else {
                rec = ServiceRecord(kind: kind, title: titleText, date: date, mileage: mileage, cost: cost, notes: notes)
                rec.vehicle = v; rec.currencyCode = v.currencyCode
                context.insert(rec)
                if alsoRemind, let interval = Int(remindIntervalText), interval > 0 {
                    let rem = Reminder(kind: kind, title: titleText, dueMileage: mileage + interval, intervalMiles: interval)
                    rem.vehicle = v; context.insert(rem)
                }
            }
            attach(to: rec)
        } else {
            let entry: FuelEntry
            if let f = editingFuel {
                f.date = date; f.mileage = mileage; f.volume = Double(volumeText) ?? 0
                f.cost = cost; f.isFull = isFull; f.notes = notes
                f.energyKindRaw = energy.rawValue; f.chargeLocationRaw = isElectric ? chargeLocation.rawValue : nil
                entry = f
            } else {
                entry = FuelEntry(date: date, mileage: mileage, volume: Double(volumeText) ?? 0, cost: cost, isFull: isFull, notes: notes,
                                  energyKind: energy, chargeLocation: isElectric ? chargeLocation : nil)
                entry.vehicle = v; entry.currencyCode = v.currencyCode
                context.insert(entry)
            }
            attach(to: entry)
        }
        if mileage > v.currentMileage { v.currentMileage = mileage }
        try? context.save()

        // Completion loop: if a recurring reminder matches this service type, offer to advance it.
        if mode == 0 && editingService == nil {
            let matches = v.reminders.filter { $0.matches(kind: kind) }
            if !matches.isEmpty {
                completionMatches = matches; savedMileage = mileage; savedDate = date
                showCompletion = true
                return
            }
        }
        finalize()
    }

    private func completeMatches() {
        for r in completionMatches { r.complete(loggedMileage: savedMileage, loggedDate: savedDate) }
        try? context.save()
        finalize()
    }

    private func finalize() {
        GarageSync.refresh(context, notifications: notifications)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }

    private func delete() {
        if let r = editingService { context.delete(r) }
        if let f = editingFuel { context.delete(f) }
        try? context.save()
        GarageSync.refresh(context, notifications: notifications)
        dismiss()
    }
}
