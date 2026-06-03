import SwiftUI
import SwiftData

struct ReminderEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var notifications: NotificationManager

    let vehicles: [Vehicle]
    var editing: Reminder?
    var presetVehicle: Vehicle?

    @State private var vehicle: Vehicle?
    @State private var kind: RecordKind = .oil
    @State private var title = ""
    @State private var mode = 0           // 0 = mileage, 1 = date
    @State private var dueMileageText = ""
    @State private var dueDate = Calendar.current.date(byAdding: .month, value: 6, to: Date()) ?? Date()
    @State private var intervalMilesText = ""
    @State private var intervalMonthsText = ""
    @State private var notify = true
    @State private var showDelete = false

    private let kinds: [RecordKind] = [.oil, .tires, .brakes, .service, .battery, .inspection, .repair, .custom]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    if vehicles.count > 1 && editing == nil { vehiclePicker }
                    if editing == nil { templateQuickStart }
                    typeGrid
                    field("Title") { TextField(kind.label, text: $title).textInputAutocapitalization(.words) }
                    modeCard
                    notifyCard
                    if editing != nil {
                        Button(role: .destructive) { showDelete = true } label: {
                            Text("Delete Reminder").appFont(16, weight: .semibold)
                                .frame(maxWidth: .infinity).padding(.vertical, 15).foregroundStyle(Theme.red)
                                .background(Theme.redSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                    Color.clear.frame(height: 20)
                }
                .padding(18)
            }
            .background(Theme.paper)
            .navigationTitle(editing == nil ? "New Reminder" : "Edit Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.foregroundStyle(Theme.ink2) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.fontWeight(.semibold)
                        .foregroundStyle(canSave ? Theme.brand : Theme.ink3).disabled(!canSave)
                }
            }
            .onAppear(perform: load)
            .confirmationDialog("Delete this reminder?", isPresented: $showDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) { delete() }
            }
        }
    }

    private var vehiclePicker: some View {
        Menu {
            ForEach(vehicles) { v in Button(v.name) { vehicle = v } }
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

    private var templateQuickStart: some View {
        Menu {
            ForEach(BuiltInTemplate.all) { t in
                Button("\(t.title) · \(t.intervalText)") { applyTemplate(t) }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "square.stack.3d.up.fill").appFont(14, weight: .semibold)
                Text("Start from a template").appFont(14, weight: .semibold)
                Spacer()
                Image(systemName: "chevron.down").appFont(11, weight: .bold)
            }
            .foregroundStyle(Theme.brand).padding(14)
            .background(Theme.brandSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func applyTemplate(_ t: BuiltInTemplate) {
        UISelectionFeedbackGenerator().selectionChanged()
        kind = t.kind; title = t.title
        if let miles = t.intervalMiles {
            mode = 0; intervalMilesText = "\(miles)"
            if let v = vehicle { dueMileageText = "\(v.currentMileage + miles)" }
        } else if let months = t.intervalMonths {
            mode = 1; intervalMonthsText = "\(months)"
            dueDate = Calendar.current.date(byAdding: .month, value: months, to: Date()) ?? Date()
        }
    }

    private var typeGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TYPE").appFont(11, weight: .bold).tracking(0.5).foregroundStyle(Theme.ink3)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                ForEach(kinds) { k in
                    Button {
                        UISelectionFeedbackGenerator().selectionChanged()
                        kind = k
                        if title.isEmpty || kinds.map(\.label).contains(title) { title = k.label }
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
        }
    }

    private var modeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("", selection: $mode) {
                Text("By mileage").tag(0)
                Text("By date").tag(1)
            }.pickerStyle(.segmented)

            if mode == 0 {
                field("Due at odometer (\(vehicle?.unit ?? "mi"))") {
                    TextField("0", text: $dueMileageText).keyboardType(.numberPad).monospacedDigit()
                }
                field("Repeat every (\(vehicle?.unit ?? "mi")) — optional") {
                    TextField("5000", text: $intervalMilesText).keyboardType(.numberPad).monospacedDigit()
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("DUE DATE").appFont(10, weight: .bold).tracking(0.5).foregroundStyle(Theme.ink3)
                    DatePicker("", selection: $dueDate, displayedComponents: .date).labelsHidden()
                }
                field("Repeat every (months) — optional") {
                    TextField("12", text: $intervalMonthsText).keyboardType(.numberPad).monospacedDigit()
                }
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.line, lineWidth: 0.75))
    }

    private var notifyCard: some View {
        Toggle(isOn: $notify) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Notify me").appFont(15, weight: .semibold).foregroundStyle(Theme.ink)
                Text(mode == 1 ? "A reminder on the due date" : "Mileage reminders show in-app")
                    .appFont(12, weight: .medium).foregroundStyle(Theme.ink2)
            }
        }
        .tint(Theme.brand)
        .padding(16)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.line, lineWidth: 0.75))
    }

    private func field<C: View>(_ label: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased()).appFont(10, weight: .bold).tracking(0.5).foregroundStyle(Theme.ink3)
            content()
                .appFont(17, weight: .medium).foregroundStyle(Theme.ink)
                .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.line, lineWidth: 0.75))
        }
    }

    private var canSave: Bool {
        guard vehicle != nil, !title.isEmpty else { return false }
        return mode == 1 || Int(dueMileageText) != nil
    }

    private func load() {
        vehicle = editing?.vehicle ?? presetVehicle ?? vehicles.first
        guard let r = editing else {
            if let v = vehicle { dueMileageText = "\(v.currentMileage + 5000)" }
            title = kind.label
            return
        }
        kind = r.kind; title = r.title; notify = r.notify
        if let dm = r.dueMileage { mode = 0; dueMileageText = "\(dm)" }
        if let dd = r.dueDate { mode = 1; dueDate = dd }
        if let im = r.intervalMiles { intervalMilesText = "\(im)" }
        if let imo = r.intervalMonths { intervalMonthsText = "\(imo)" }
    }

    private func save() {
        guard let v = vehicle else { return }
        let target = editing ?? Reminder(kind: kind, title: title)
        target.kindRaw = kind.rawValue
        target.title = title
        target.notify = notify
        if mode == 0 {
            target.dueMileage = Int(dueMileageText)
            target.dueDate = nil
            target.intervalMiles = Int(intervalMilesText)
            target.intervalMonths = nil
        } else {
            target.dueDate = dueDate
            target.dueMileage = nil
            target.intervalMonths = Int(intervalMonthsText)
            target.intervalMiles = nil
        }
        if editing == nil {
            target.vehicle = v
            context.insert(target)
        }
        try? context.save()
        GarageSync.refresh(context, notifications: notifications)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }

    private func delete() {
        guard let r = editing else { return }
        context.delete(r)
        try? context.save()
        GarageSync.refresh(context, notifications: notifications)
        dismiss()
    }
}
