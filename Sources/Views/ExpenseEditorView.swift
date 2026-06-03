import SwiftUI
import SwiftData
import PhotosUI

struct ExpenseEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var notifications: NotificationManager

    let vehicles: [Vehicle]
    var editing: Expense?

    @State private var vehicle: Vehicle?
    @State private var category: ExpenseCategory = .insurance
    @State private var amountText = ""
    @State private var date = Date()
    @State private var mileageText = ""
    @State private var note = ""
    @State private var recurrence: Recurrence = .none
    @State private var photos: [Data] = []
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showDelete = false

    init(vehicles: [Vehicle], editing: Expense? = nil, preselected: Vehicle? = nil) {
        self.vehicles = vehicles
        self.editing = editing
        _vehicle = State(initialValue: editing?.vehicle ?? preselected ?? vehicles.first)
    }

    private let cats = ExpenseCategory.allCases

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    if vehicles.count > 1 && editing == nil { vehiclePicker }
                    categoryGrid
                    field("Amount") {
                        HStack(spacing: 2) {
                            Text(Currencies.symbol(vehicle?.currencyCode ?? "USD")).foregroundStyle(Theme.ink2)
                            TextField("0.00", text: $amountText).keyboardType(.decimalPad).monospacedDigit()
                        }
                    }
                    field("Date") { DatePicker("", selection: $date, displayedComponents: .date).labelsHidden() }
                    recurrenceCard
                    field("Odometer — optional (\(vehicle?.unit ?? "mi"))") {
                        TextField("0", text: $mileageText).keyboardType(.numberPad).monospacedDigit()
                    }
                    field("Note") { TextField("Optional", text: $note, axis: .vertical).lineLimit(1...3) }
                    photoField
                    if editing != nil {
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
            .navigationTitle(editing == nil ? "Log Expense" : "Edit Expense")
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
            .confirmationDialog("Delete this expense?", isPresented: $showDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) { delete() }
            }
        }
        .presentationDragIndicator(.visible)
    }

    private var vehiclePicker: some View {
        Menu {
            ForEach(vehicles) { v in Button(v.name) { vehicle = v } }
        } label: {
            HStack {
                Image(systemName: "car.fill").foregroundStyle(vehicle?.accent ?? Theme.ink2)
                Text(vehicle?.name ?? "Select vehicle").foregroundStyle(Theme.ink).fontWeight(.semibold)
                Spacer(); Image(systemName: "chevron.up.chevron.down").appFont(12, weight: .bold).foregroundStyle(Theme.ink3)
            }
            .padding(14).background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.line, lineWidth: 0.75))
        }
    }

    private var categoryGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CATEGORY").appFont(11, weight: .bold).tracking(0.5).foregroundStyle(Theme.ink3)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                ForEach(cats) { c in
                    Button {
                        UISelectionFeedbackGenerator().selectionChanged(); category = c
                        if recurrence == .none && (c == .insurance || c == .loan) { recurrence = .monthly }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: c.symbol).appFont(17, weight: .semibold).foregroundStyle(category == c ? .white : c.tint)
                            Text(c.label).appFont(10, weight: .semibold).lineLimit(1).minimumScaleFactor(0.7).foregroundStyle(category == c ? .white : Theme.ink2)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 11)
                        .background(category == c ? Theme.brand : Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.line, lineWidth: category == c ? 0 : 0.75))
                    }.buttonStyle(.plain)
                }
            }
        }
    }

    private var recurrenceCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("REPEATS").appFont(10, weight: .bold).tracking(0.5).foregroundStyle(Theme.ink3)
            Picker("", selection: $recurrence) {
                ForEach(Recurrence.allCases) { Text($0.label).tag($0) }
            }.pickerStyle(.segmented)
            if recurrence != .none {
                Text("We'll remind you before the next \(category.label.lowercased()) is due.")
                    .appFont(12, weight: .medium).foregroundStyle(Theme.ink2)
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.line, lineWidth: 0.75))
    }

    private var photoField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RECEIPTS").appFont(11, weight: .bold).tracking(0.5).foregroundStyle(Theme.ink3)
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
                        Image(systemName: "photo.on.rectangle").appFont(20, weight: .semibold).foregroundStyle(Theme.ink3)
                            .frame(width: 92, height: 92).background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.line, lineWidth: 0.75))
                    }
                }
            }
        }
    }

    private func field<C: View>(_ label: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased()).appFont(11, weight: .bold).tracking(0.5).foregroundStyle(Theme.ink3)
            content().appFont(17, weight: .medium).foregroundStyle(Theme.ink)
                .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.line, lineWidth: 0.75))
        }
    }

    private var canSave: Bool { vehicle != nil && Double(amountText) != nil }

    private func load() {
        guard let e = editing else { return }
        category = e.category; amountText = String(format: "%.2f", e.amount); date = e.date
        if let m = e.mileage { mileageText = "\(m)" }
        note = e.note; recurrence = e.recurrence
        photos = e.attachments.map(\.data)
    }

    private func save() {
        guard let v = vehicle, let amount = Double(amountText) else { return }
        let target: Expense
        if let e = editing {
            e.categoryRaw = category.rawValue; e.amount = amount; e.date = date
            e.mileage = Int(mileageText); e.note = note; e.recurrenceRaw = recurrence.rawValue
            target = e
        } else {
            target = Expense(category: category, amount: amount, date: date, mileage: Int(mileageText),
                             note: note, recurrence: recurrence, currencyCode: v.currencyCode)
            target.vehicle = v
            context.insert(target)
            // Recurring expense → a date reminder so renewals never lapse.
            if let months = recurrence.months {
                let rem = Reminder(kind: .custom, title: "\(category.label) renewal",
                                   dueDate: Calendar.current.date(byAdding: .month, value: months, to: date),
                                   intervalMonths: months)
                rem.vehicle = v; context.insert(rem)
            }
        }
        for a in target.attachments { context.delete(a) }
        for d in photos { let a = Attachment(kind: "photo", filename: "receipt.jpg", data: d); a.expense = target; context.insert(a) }
        try? context.save()
        GarageSync.refresh(context, notifications: notifications)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }

    private func delete() {
        if let e = editing { context.delete(e); try? context.save(); GarageSync.refresh(context, notifications: notifications) }
        dismiss()
    }
}
