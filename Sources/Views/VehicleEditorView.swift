import SwiftUI
import SwiftData
import PhotosUI

struct VehicleEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var notifications: NotificationManager

    var editing: Vehicle?

    @State private var name = ""
    @State private var make = ""
    @State private var model = ""
    @State private var yearText = ""
    @State private var mileageText = ""
    @State private var unit = "mi"
    @State private var fuelUnit = "gal"
    @State private var powertrain: Powertrain = .gas
    @State private var currencyCode = "USD"
    @State private var colorHex: UInt = 0xED5B22
    @State private var photoData: Data?
    @State private var pickerItem: PhotosPickerItem?
    @State private var showDeleteConfirm = false

    private let palette: [UInt] = [0xED5B22, 0x202724, 0x3B7DD8, 0x2E6F73, 0x2E9E6B, 0x8A5CF6, 0xD64570, 0xB58A2E]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    photoHeader
                    group("IDENTITY") {
                        field("Name") { TextField("My car", text: $name).textInputAutocapitalization(.words) }
                        HStack(spacing: 12) {
                            field("Make") { TextField("Honda", text: $make).textInputAutocapitalization(.words) }
                            field("Model") { TextField("Civic", text: $model).textInputAutocapitalization(.words) }
                        }
                        field("Year") { TextField("2021", text: $yearText).keyboardType(.numberPad).monospacedDigit() }
                    }
                    group("POWERTRAIN") {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("TYPE").appFont(10, weight: .bold).tracking(0.5).foregroundStyle(Theme.ink3)
                            Picker("", selection: $powertrain) {
                                ForEach(Powertrain.allCases) { Text($0.label).tag($0) }
                            }.pickerStyle(.segmented)
                        }
                    }
                    group("ODOMETER & UNITS") {
                        field("Current odometer") {
                            HStack {
                                TextField("0", text: $mileageText).keyboardType(.numberPad).monospacedDigit()
                                Text(unit).foregroundStyle(Theme.ink3)
                            }
                        }
                        segmented("Distance", options: [("mi", "Miles"), ("km", "Kilometers")], selection: $unit)
                        if powertrain.usesLiquidFuel {
                            segmented("Fuel", options: [("gal", "Gallons"), ("L", "Liters")], selection: $fuelUnit)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("CURRENCY").appFont(10, weight: .bold).tracking(0.5).foregroundStyle(Theme.ink3)
                            Menu {
                                ForEach(Currencies.codes, id: \.self) { c in Button("\(c) · \(Currencies.symbol(c))") { currencyCode = c } }
                            } label: {
                                HStack {
                                    Text("\(currencyCode) · \(Currencies.symbol(currencyCode))").foregroundStyle(Theme.ink).appFont(17, weight: .medium)
                                    Spacer(); Image(systemName: "chevron.up.chevron.down").appFont(12, weight: .bold).foregroundStyle(Theme.ink3)
                                }
                                .padding(12).background(Theme.surface2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                        }
                    }
                    colorPicker
                    if editing != nil {
                        Button(role: .destructive) { showDeleteConfirm = true } label: {
                            Text("Delete Vehicle").appFont(16, weight: .semibold)
                                .frame(maxWidth: .infinity).padding(.vertical, 15)
                                .foregroundStyle(Theme.red)
                                .background(Theme.redSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                    Color.clear.frame(height: 20)
                }
                .padding(18)
            }
            .background(Theme.paper)
            .navigationTitle(editing == nil ? "Add Vehicle" : "Edit Vehicle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.foregroundStyle(Theme.ink2) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.fontWeight(.semibold)
                        .foregroundStyle(canSave ? Theme.brand : Theme.ink3).disabled(!canSave)
                }
            }
            .onAppear(perform: load)
            .onChange(of: pickerItem) { _, item in
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self),
                       let img = UIImage(data: data) { photoData = img.jpegForStorage() }
                }
            }
            .confirmationDialog("Delete this vehicle and all its records?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete Vehicle", role: .destructive) { delete() }
            }
        }
    }

    private var photoHeader: some View {
        PhotosPicker(selection: $pickerItem, matching: .images) {
            ZStack {
                if let photoData, let img = UIImage(data: photoData) {
                    Image(uiImage: img).resizable().scaledToFill()
                } else {
                    Color(hex: colorHex).opacity(0.16)
                    VStack(spacing: 8) {
                        Image(systemName: "car.fill").appFont(30, weight: .semibold).foregroundStyle(Color(hex: colorHex))
                        Text("Add photo").appFont(13, weight: .semibold).foregroundStyle(Theme.ink2)
                    }
                }
            }
            .frame(height: 150).frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.line, lineWidth: 0.75))
        }
    }

    private var colorPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ACCENT").appFont(11, weight: .bold).tracking(0.5).foregroundStyle(Theme.ink3)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 12) {
                ForEach(palette, id: \.self) { hex in
                    Circle().fill(Color(hex: hex))
                        .frame(height: 30)
                        .overlay(Circle().stroke(Theme.ink, lineWidth: colorHex == hex ? 2.5 : 0).padding(-3))
                        .onTapGesture { UISelectionFeedbackGenerator().selectionChanged(); colorHex = hex }
                }
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.line, lineWidth: 0.75))
    }

    // MARK: building blocks

    private func group<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).appFont(11, weight: .bold).tracking(0.5).foregroundStyle(Theme.ink3)
            content()
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.line, lineWidth: 0.75))
    }

    private func field<C: View>(_ label: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased()).appFont(10, weight: .bold).tracking(0.5).foregroundStyle(Theme.ink3)
            content()
                .appFont(17, weight: .medium).foregroundStyle(Theme.ink)
                .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func segmented(_ label: String, options: [(String, String)], selection: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased()).appFont(10, weight: .bold).tracking(0.5).foregroundStyle(Theme.ink3)
            Picker(label, selection: selection) {
                ForEach(options, id: \.0) { Text($0.1).tag($0.0) }
            }.pickerStyle(.segmented)
        }
    }

    // MARK: logic

    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    private func load() {
        guard let v = editing else { return }
        name = v.name; make = v.make; model = v.modelName
        yearText = v.year > 0 ? "\(v.year)" : ""
        mileageText = "\(v.currentMileage)"
        unit = v.unit; fuelUnit = v.fuelUnit; colorHex = v.colorHex; photoData = v.photoData
        powertrain = v.powertrain; currencyCode = v.currencyCode
    }

    private func save() {
        let year = Int(yearText) ?? 0
        let mileage = Int(mileageText) ?? 0
        if let v = editing {
            v.name = name; v.make = make; v.modelName = model; v.year = year
            v.currentMileage = mileage; v.unit = unit; v.fuelUnit = fuelUnit
            v.colorHex = colorHex; v.photoData = photoData
            v.powertrainRaw = powertrain.rawValue; v.currencyCode = currencyCode
        } else {
            let v = Vehicle(name: name, make: make, modelName: model, year: year,
                            colorHex: colorHex, currentMileage: mileage, unit: unit, fuelUnit: fuelUnit,
                            powertrain: powertrain, currencyCode: currencyCode)
            v.photoData = photoData
            context.insert(v)
            seedStandardReminders(for: v, mileage: mileage)
        }
        try? context.save()
        GarageSync.refresh(context, notifications: notifications)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }

    private func delete() {
        guard let v = editing else { return }
        context.delete(v)
        try? context.save()
        GarageSync.refresh(context, notifications: notifications)
        dismiss()
    }

    // New vehicles land in a populated garage with sensible default reminders.
    // EVs skip the oil change and get a brake-fluid item instead.
    private func seedStandardReminders(for v: Vehicle, mileage: Int) {
        if powertrain.usesLiquidFuel {
            let oil = Reminder(kind: .oil, title: "Oil change", dueMileage: mileage + 5_000, intervalMiles: 5_000)
            oil.vehicle = v; context.insert(oil)
        } else {
            let bf = Reminder(kind: .service, title: "Brake fluid", dueMileage: mileage + 20_000, intervalMiles: 20_000)
            bf.vehicle = v; context.insert(bf)
        }
        let tires = Reminder(kind: .tires, title: "Tire rotation", dueMileage: mileage + 6_000, intervalMiles: 6_000)
        tires.vehicle = v
        let reg = Reminder(kind: .inspection, title: "Registration / inspection",
                           dueDate: Calendar.current.date(byAdding: .month, value: 12, to: Date()), intervalMonths: 12)
        reg.vehicle = v
        context.insert(tires); context.insert(reg)
    }
}
