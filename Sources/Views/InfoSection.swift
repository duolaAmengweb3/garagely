import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers
import Charts

struct InfoSection: View {
    @Bindable var vehicle: Vehicle
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var notifications: NotificationManager
    @EnvironmentObject private var purchases: PurchaseManager

    @State private var editingSpec: SpecPair?
    @State private var showAddSpec = false
    @State private var showAddDoc = false
    @State private var showAddReading = false
    @State private var editingReading: EVReading?
    @State private var previewURL: URL?
    @State private var showPaywall = false
    @State private var showArchiveConfirm = false

    var body: some View {
        VStack(spacing: 16) {
            if vehicle.powertrain.usesElectric { batteryCard }
            specsCard
            gloveboxCard
            ownershipCard
        }
        .sheet(isPresented: $showAddSpec) { SpecEditorSheet(vehicle: vehicle) }
        .sheet(item: $editingSpec) { sp in SpecEditorSheet(vehicle: vehicle, editing: sp) }
        .sheet(isPresented: $showAddDoc) { DocumentAddSheet(vehicle: vehicle) }
        .sheet(isPresented: $showAddReading) { EVReadingEditorView(vehicle: vehicle) }
        .sheet(item: $editingReading) { r in EVReadingEditorView(vehicle: vehicle, editing: r) }
        .sheet(item: $previewURL) { url in ShareSheet(items: [url]) }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .confirmationDialog("Archive \(vehicle.name)? It moves out of your garage but keeps all records.", isPresented: $showArchiveConfirm, titleVisibility: .visible) {
            Button("Archive Vehicle") { vehicle.isArchived = true; try? context.save(); GarageSync.refresh(context, notifications: notifications); dismiss() }
        }
    }

    // MARK: Battery health (EV/PHEV)

    private var batteryCard: some View {
        let readings = vehicle.evReadings.sorted { $0.date < $1.date }
        let latest = readings.last
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(title: "Battery Health")
                Button { showAddReading = true } label: { Image(systemName: "plus.circle.fill").appFont(20).foregroundStyle(Theme.brand) }
            }
            if readings.isEmpty {
                Text("Log estimated range or battery health to watch for degradation over time.").appFont(13, weight: .medium).foregroundStyle(Theme.ink2)
            } else {
                HStack(spacing: 16) {
                    if let soh = latest?.sohPercent {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("HEALTH").appFont(10, weight: .bold).tracking(0.5).foregroundStyle(Theme.ink3)
                            Text("\(Int(soh))%").appFont(28, weight: .bold, design: .rounded).foregroundStyle(Theme.green).monospacedDigit()
                        }
                    }
                    if let range = latest?.estRangeMiles {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("RANGE").appFont(10, weight: .bold).tracking(0.5).foregroundStyle(Theme.ink3)
                            Text("\(range) \(vehicle.unit)").appFont(28, weight: .bold, design: .rounded).foregroundStyle(Theme.blue).monospacedDigit()
                        }
                    }
                    Spacer()
                }
                if readings.count >= 2 {
                    Chart(readings) { r in
                        if let soh = r.sohPercent {
                            LineMark(x: .value("Date", r.date), y: .value("SoH", soh))
                                .foregroundStyle(Theme.green).interpolationMethod(.catmullRom)
                            PointMark(x: .value("Date", r.date), y: .value("SoH", soh)).foregroundStyle(Theme.green)
                        }
                    }
                    .frame(height: 90).chartYScale(domain: 70...100).chartYAxis { AxisMarks(position: .leading) }
                }
                VStack(spacing: 0) {
                    ForEach(Array(readings.reversed().enumerated()), id: \.element.id) { idx, r in
                        Button { editingReading = r } label: {
                            HStack {
                                Text(r.date.shortLabel).appFont(13, weight: .medium).foregroundStyle(Theme.ink2)
                                Spacer()
                                if let soh = r.sohPercent { Text("\(Int(soh))%").appFont(13, weight: .semibold).foregroundStyle(Theme.green) }
                                if let range = r.estRangeMiles { Text("· \(range) \(vehicle.unit)").appFont(13, weight: .semibold).foregroundStyle(Theme.blue) }
                                Image(systemName: "chevron.right").appFont(11, weight: .bold).foregroundStyle(Theme.ink3)
                            }
                            .padding(.vertical, 9)
                        }.buttonStyle(.plain)
                        if idx < readings.count - 1 { Divider().overlay(Theme.line) }
                    }
                }
            }
        }
        .card(padding: 16, radius: 20)
    }

    // MARK: Specs

    private var specsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(title: "Specs")
                Button { showAddSpec = true } label: { Image(systemName: "plus.circle.fill").appFont(20).foregroundStyle(Theme.brand) }
            }
            if vehicle.specPairs.isEmpty {
                Text("Save filter numbers, bulb sizes, tire size & PSI — handy at the parts counter.").appFont(13, weight: .medium).foregroundStyle(Theme.ink2)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(vehicle.specPairs.enumerated()), id: \.element.id) { idx, sp in
                        Button { editingSpec = sp } label: {
                            HStack {
                                Text(sp.label).appFont(14, weight: .medium).foregroundStyle(Theme.ink2)
                                Spacer()
                                Text(sp.value).appFont(14, weight: .semibold).foregroundStyle(Theme.ink)
                                Image(systemName: "chevron.right").appFont(11, weight: .bold).foregroundStyle(Theme.ink3)
                            }
                            .padding(.vertical, 11)
                        }.buttonStyle(.plain)
                        if idx < vehicle.specPairs.count - 1 { Divider().overlay(Theme.line) }
                    }
                }
            }
        }
        .card(padding: 16, radius: 20)
    }

    // MARK: Glovebox

    private var gloveboxCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(title: "Glovebox")
                Button { showAddDoc = true } label: { Image(systemName: "plus.circle.fill").appFont(20).foregroundStyle(Theme.brand) }
            }
            if vehicle.documents.isEmpty {
                Text("Keep insurance, registration and warranty documents on hand — with expiry reminders.").appFont(13, weight: .medium).foregroundStyle(Theme.ink2)
            } else {
                VStack(spacing: 0) {
                    let docs = vehicle.documents.sorted { $0.createdAt > $1.createdAt }
                    ForEach(Array(docs.enumerated()), id: \.element.id) { idx, doc in
                        Button { preview(doc) } label: {
                            HStack(spacing: 12) {
                                Image(systemName: doc.isDocument ? "doc.fill" : "photo.fill").appFont(15, weight: .semibold).foregroundStyle(Theme.blue).frame(width: 38, height: 38)
                                    .background(Theme.blueSoft, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(doc.filename).appFont(15, weight: .semibold).foregroundStyle(Theme.ink).lineLimit(1)
                                    if let exp = doc.expiryDate {
                                        Text("Expires \(exp.shortLabel)").appFont(12, weight: .medium)
                                            .foregroundStyle(exp < Date() ? Theme.red : Theme.ink2)
                                    }
                                }
                                Spacer()
                                Image(systemName: "square.and.arrow.up").appFont(13, weight: .semibold).foregroundStyle(Theme.ink3)
                            }
                            .padding(.vertical, 8)
                        }.buttonStyle(.plain)
                        if idx < docs.count - 1 { Divider().overlay(Theme.line).padding(.leading, 50) }
                    }
                }
            }
        }
        .card(padding: 16, radius: 20)
    }

    // MARK: Ownership (archive + buyer report)

    private var ownershipCard: some View {
        VStack(spacing: 0) {
            Button { exportHistory() } label: {
                row("doc.richtext.fill", "Vehicle History Report", trailing: purchases.isPro ? "PDF" : "Pro")
            }.buttonStyle(.plain)
            Divider().overlay(Theme.line).padding(.leading, 52)
            Button { showArchiveConfirm = true } label: {
                row("archivebox.fill", "Archive (sold)", trailing: nil)
            }.buttonStyle(.plain)
        }
        .card(padding: 0, radius: 20)
    }

    private func row(_ icon: String, _ title: String, trailing: String?) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).appFont(15, weight: .semibold).foregroundStyle(Theme.brand).frame(width: 26)
            Text(title).appFont(15, weight: .medium).foregroundStyle(Theme.ink)
            Spacer()
            if let trailing { Text(trailing).appFont(14, weight: .semibold).foregroundStyle(trailing == "Pro" ? Theme.brand : Theme.ink2) }
            Image(systemName: "chevron.right").appFont(12, weight: .bold).foregroundStyle(Theme.ink3)
        }
        .padding(14)
    }

    private func exportHistory() {
        guard purchases.isPro else { showPaywall = true; return }
        previewURL = ExportManager.pdf(for: vehicle)
    }

    private func preview(_ doc: Attachment) {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(doc.filename.isEmpty ? "document" : doc.filename)
        try? doc.data.write(to: url)
        previewURL = url
    }
}

// MARK: - Spec editor

struct SpecEditorSheet: View {
    @Bindable var vehicle: Vehicle
    var editing: SpecPair?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var label = ""
    @State private var value = ""

    private let suggestions = ["Oil filter", "Air filter", "Cabin filter", "Wiper size", "Headlight bulb",
                               "Tire size", "Tire PSI (front)", "Tire PSI (rear)", "Battery group", "Oil type", "Torque"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    field("Label") { TextField("Oil filter", text: $label) }
                    if editing == nil {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(suggestions, id: \.self) { s in
                                    Button { label = s } label: {
                                        Text(s).appFont(13, weight: .semibold).foregroundStyle(Theme.ink2)
                                            .padding(.horizontal, 12).padding(.vertical, 7)
                                            .background(Theme.surface, in: Capsule())
                                            .overlay(Capsule().stroke(Theme.line, lineWidth: 0.75))
                                    }.buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    field("Value") { TextField("e.g. PH7317 / 35 PSI", text: $value) }
                    if editing != nil {
                        Button(role: .destructive) { remove() } label: {
                            Text("Delete").appFont(16, weight: .semibold).frame(maxWidth: .infinity).padding(.vertical, 15)
                                .foregroundStyle(Theme.red).background(Theme.redSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                }
                .padding(18)
            }
            .background(Theme.paper)
            .navigationTitle(editing == nil ? "Add Spec" : "Edit Spec")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.foregroundStyle(Theme.ink2) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.appFont(17, weight: .semibold)
                        .foregroundStyle(label.isEmpty ? Theme.ink3 : Theme.brand).disabled(label.isEmpty)
                }
            }
            .onAppear { if let e = editing { label = e.label; value = e.value } }
        }
        .presentationDetents([.medium])
    }

    private func field<C: View>(_ l: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(l.uppercased()).appFont(11, weight: .bold).tracking(0.5).foregroundStyle(Theme.ink3)
            content().appFont(17, weight: .medium).foregroundStyle(Theme.ink)
                .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.line, lineWidth: 0.75))
        }
    }

    private func save() {
        if let e = editing, let idx = vehicle.specPairs.firstIndex(where: { $0.id == e.id }) {
            vehicle.specPairs[idx].label = label; vehicle.specPairs[idx].value = value
        } else {
            vehicle.specPairs.append(SpecPair(label: label, value: value))
        }
        try? context.save(); dismiss()
    }
    private func remove() {
        if let e = editing { vehicle.specPairs.removeAll { $0.id == e.id }; try? context.save() }
        dismiss()
    }
}

// MARK: - Document add (glovebox)

struct DocumentAddSheet: View {
    @Bindable var vehicle: Vehicle
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var notifications: NotificationManager

    @State private var name = ""
    @State private var data: Data?
    @State private var isDoc = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var hasExpiry = false
    @State private var expiry = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var showFileImporter = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    field("Name") { TextField("Insurance card", text: $name) }
                    HStack(spacing: 12) {
                        PhotosPicker(selection: $pickerItem, matching: .images) { pickTile("Photo", "photo.on.rectangle") }
                        Button { showFileImporter = true } label: { pickTile("PDF / File", "doc.fill") }
                    }
                    if data != nil {
                        Label("Attached", systemImage: "checkmark.circle.fill").appFont(14, weight: .semibold).foregroundStyle(Theme.green)
                    }
                    Toggle(isOn: $hasExpiry) { Text("Has expiry date").appFont(15, weight: .semibold).foregroundStyle(Theme.ink) }
                        .tint(Theme.brand).padding(14).background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.line, lineWidth: 0.75))
                    if hasExpiry {
                        field("Expires") { DatePicker("", selection: $expiry, displayedComponents: .date).labelsHidden() }
                    }
                }
                .padding(18)
            }
            .background(Theme.paper)
            .navigationTitle("Add Document")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.foregroundStyle(Theme.ink2) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.appFont(17, weight: .semibold)
                        .foregroundStyle(canSave ? Theme.brand : Theme.ink3).disabled(!canSave)
                }
            }
            .onChange(of: pickerItem) { _, item in
                Task { if let d = try? await item?.loadTransferable(type: Data.self), let img = UIImage(data: d) { data = img.jpegForStorage(); isDoc = false } }
            }
            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.pdf, .image, .data]) { result in
                if case .success(let url) = result {
                    if url.startAccessingSecurityScopedResource() {
                        data = try? Data(contentsOf: url); isDoc = true
                        if name.isEmpty { name = url.deletingPathExtension().lastPathComponent }
                        url.stopAccessingSecurityScopedResource()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var canSave: Bool { data != nil && !name.isEmpty }

    private func pickTile(_ label: String, _ icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).appFont(18, weight: .semibold)
            Text(label).appFont(13, weight: .semibold)
        }
        .foregroundStyle(Theme.ink2).frame(maxWidth: .infinity).padding(.vertical, 16)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.line, lineWidth: 0.75))
    }

    private func field<C: View>(_ l: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(l.uppercased()).appFont(11, weight: .bold).tracking(0.5).foregroundStyle(Theme.ink3)
            content().appFont(17, weight: .medium).foregroundStyle(Theme.ink)
                .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.line, lineWidth: 0.75))
        }
    }

    private func save() {
        guard let data else { return }
        let ext = isDoc ? "pdf" : "jpg"
        let a = Attachment(kind: isDoc ? "document" : "photo", filename: "\(name).\(ext)", data: data, expiryDate: hasExpiry ? expiry : nil)
        a.vehicle = vehicle
        context.insert(a)
        if hasExpiry {
            let rem = Reminder(kind: .inspection, title: "\(name) expires", dueDate: expiry)
            rem.vehicle = vehicle; context.insert(rem)
        }
        try? context.save()
        GarageSync.refresh(context, notifications: notifications)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}

// MARK: - EV reading editor

struct EVReadingEditorView: View {
    @Bindable var vehicle: Vehicle
    var editing: EVReading?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var notifications: NotificationManager

    @State private var date = Date()
    @State private var mileageText = ""
    @State private var rangeText = ""
    @State private var sohText = ""
    @State private var showDelete = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    field("Date") { DatePicker("", selection: $date, displayedComponents: .date).labelsHidden() }
                    field("Odometer (\(vehicle.unit))") { TextField("0", text: $mileageText).keyboardType(.numberPad).monospacedDigit() }
                    field("Estimated range (\(vehicle.unit)) — optional") { TextField("0", text: $rangeText).keyboardType(.numberPad).monospacedDigit() }
                    field("Battery health % — optional") { TextField("100", text: $sohText).keyboardType(.decimalPad).monospacedDigit() }
                    if editing != nil {
                        Button(role: .destructive) { showDelete = true } label: {
                            Text("Delete").appFont(16, weight: .semibold).frame(maxWidth: .infinity).padding(.vertical, 15)
                                .foregroundStyle(Theme.red).background(Theme.redSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                    Color.clear.frame(height: 16)
                }
                .padding(18)
            }
            .background(Theme.paper)
            .navigationTitle(editing == nil ? "Log Battery Reading" : "Edit Reading")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.foregroundStyle(Theme.ink2) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.appFont(17, weight: .semibold)
                        .foregroundStyle(Int(mileageText) != nil ? Theme.brand : Theme.ink3).disabled(Int(mileageText) == nil)
                }
            }
            .onAppear {
                if let r = editing { date = r.date; mileageText = "\(r.mileage)"; rangeText = r.estRangeMiles.map { "\($0)" } ?? ""; sohText = r.sohPercent.map { String(format: "%.0f", $0) } ?? "" }
                else { mileageText = "\(vehicle.currentMileage)" }
            }
            .confirmationDialog("Delete this reading?", isPresented: $showDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) { if let r = editing { context.delete(r); try? context.save() }; dismiss() }
            }
        }
        .presentationDetents([.medium])
    }

    private func field<C: View>(_ l: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(l.uppercased()).appFont(11, weight: .bold).tracking(0.5).foregroundStyle(Theme.ink3)
            content().appFont(17, weight: .medium).foregroundStyle(Theme.ink)
                .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.line, lineWidth: 0.75))
        }
    }

    private func save() {
        guard let mileage = Int(mileageText) else { return }
        if let r = editing {
            r.date = date; r.mileage = mileage; r.estRangeMiles = Int(rangeText); r.sohPercent = Double(sohText)
        } else {
            let r = EVReading(date: date, mileage: mileage, estRangeMiles: Int(rangeText), sohPercent: Double(sohText))
            r.vehicle = vehicle; context.insert(r)
        }
        if mileage > vehicle.currentMileage { vehicle.currentMileage = mileage }
        try? context.save()
        GarageSync.refresh(context, notifications: notifications)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}
