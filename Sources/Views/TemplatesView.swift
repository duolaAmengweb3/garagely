import SwiftUI
import SwiftData

struct TemplatesView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var notifications: NotificationManager
    @Query private var vehicles: [Vehicle]
    @Query(sort: \ServiceTemplate.createdAt) private var custom: [ServiceTemplate]

    @State private var showAdd = false
    @State private var applying: ApplyTarget?
    @State private var toast: String?

    private struct ApplyTarget: Identifiable { let id = UUID(); let kind: RecordKind; let title: String; let miles: Int?; let months: Int? }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                group("BUILT-IN") {
                    ForEach(Array(BuiltInTemplate.all.enumerated()), id: \.element.id) { idx, t in
                        templateRow(kind: t.kind, title: t.title, interval: t.intervalText) {
                            applying = ApplyTarget(kind: t.kind, title: t.title, miles: t.intervalMiles, months: t.intervalMonths)
                        }
                        if idx < BuiltInTemplate.all.count - 1 { divider }
                    }
                }
                if !custom.isEmpty {
                    group("MY TEMPLATES") {
                        ForEach(Array(custom.enumerated()), id: \.element.id) { idx, t in
                            templateRow(kind: t.kind, title: t.title, interval: t.intervalText, onDelete: { delete(t) }) {
                                applying = ApplyTarget(kind: t.kind, title: t.title, miles: t.intervalMiles, months: t.intervalMonths)
                            }
                            if idx < custom.count - 1 { divider }
                        }
                    }
                }
                Color.clear.frame(height: 60)
            }
            .padding(18)
        }
        .screenBackground()
        .navigationTitle("Service Templates")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAdd = true } label: { Image(systemName: "plus").fontWeight(.bold) }.foregroundStyle(Theme.brand)
            }
        }
        .sheet(isPresented: $showAdd) { TemplateEditorView() }
        .confirmationDialog("Apply to which vehicle?", isPresented: Binding(get: { applying != nil }, set: { if !$0 { applying = nil } }), titleVisibility: .visible) {
            if let t = applying {
                ForEach(vehicles) { v in
                    Button(v.name) { apply(t, to: v) }
                }
            }
        }
        .overlay(alignment: .bottom) {
            if let toast {
                Text(toast).appFont(14, weight: .semibold).foregroundStyle(.white)
                    .padding(.horizontal, 18).padding(.vertical, 12)
                    .background(Theme.graphite, in: Capsule()).padding(.bottom, 30)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private func templateRow(kind: RecordKind, title: String, interval: String, onDelete: (() -> Void)? = nil, apply: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            KindIcon(kind: kind, size: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).appFont(15, weight: .semibold).foregroundStyle(Theme.ink)
                Text(interval).appFont(13, weight: .medium).foregroundStyle(Theme.ink2)
            }
            Spacer()
            if let onDelete {
                Button(action: onDelete) { Image(systemName: "trash").appFont(13, weight: .semibold).foregroundStyle(Theme.red) }
                    .buttonStyle(.plain).padding(.trailing, 4)
            }
            Button(action: apply) {
                Text("Apply").appFont(13, weight: .bold).foregroundStyle(Theme.brand)
                    .padding(.horizontal, 12).padding(.vertical, 6).background(Theme.brandSoft, in: Capsule())
            }.buttonStyle(.plain).disabled(vehicles.isEmpty)
        }
        .padding(14)
    }

    private func group<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).appFont(11, weight: .bold).tracking(0.5).foregroundStyle(Theme.ink3).padding(.leading, 4)
            VStack(spacing: 0) { content() }.card(padding: 0, radius: 18)
        }
    }
    private var divider: some View { Divider().overlay(Theme.line).padding(.leading, 52) }

    private func apply(_ t: ApplyTarget, to v: Vehicle) {
        let rem = Reminder(kind: t.kind, title: t.title, intervalMonths: t.months, intervalMiles: t.miles)
        if let miles = t.miles { rem.dueMileage = v.currentMileage + miles }
        else if let months = t.months { rem.dueDate = Calendar.current.date(byAdding: .month, value: months, to: Date()) }
        rem.vehicle = v
        context.insert(rem)
        try? context.save()
        GarageSync.refresh(context, notifications: notifications)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation { toast = "Added to \(v.name)" }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { withAnimation { toast = nil } }
    }

    private func delete(_ t: ServiceTemplate) {
        context.delete(t); try? context.save()
    }
}

// MARK: - Custom template editor

struct TemplateEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var kind: RecordKind = .oil
    @State private var title = ""
    @State private var milesText = ""
    @State private var monthsText = ""

    private let kinds: [RecordKind] = [.oil, .tires, .brakes, .service, .battery, .inspection, .repair, .custom]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("TYPE").appFont(11, weight: .bold).tracking(0.5).foregroundStyle(Theme.ink3)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                            ForEach(kinds) { k in
                                Button {
                                    UISelectionFeedbackGenerator().selectionChanged(); kind = k
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
                    field("Title") { TextField(kind.label, text: $title).textInputAutocapitalization(.words) }
                    HStack(spacing: 12) {
                        field("Every (mi)") { TextField("5000", text: $milesText).keyboardType(.numberPad).monospacedDigit() }
                        field("Every (months)") { TextField("12", text: $monthsText).keyboardType(.numberPad).monospacedDigit() }
                    }
                    Color.clear.frame(height: 20)
                }
                .padding(18)
            }
            .background(Theme.paper)
            .navigationTitle("New Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.foregroundStyle(Theme.ink2) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.fontWeight(.semibold)
                        .foregroundStyle(title.isEmpty ? Theme.ink3 : Theme.brand).disabled(title.isEmpty)
                }
            }
        }
    }

    private func field<C: View>(_ label: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased()).appFont(10, weight: .bold).tracking(0.5).foregroundStyle(Theme.ink3)
            content().appFont(17, weight: .medium).foregroundStyle(Theme.ink)
                .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.line, lineWidth: 0.75))
        }
    }

    private func save() {
        let t = ServiceTemplate(kind: kind, title: title, intervalMiles: Int(milesText), intervalMonths: Int(monthsText))
        context.insert(t); try? context.save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}
