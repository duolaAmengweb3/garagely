import Foundation
import SwiftData
import SwiftUI

// MARK: - Record categories

enum RecordKind: String, CaseIterable, Codable, Identifiable {
    case oil, tires, brakes, service, repair, battery, inspection, custom
    var id: String { rawValue }

    var label: String {
        switch self {
        case .oil:        return "Oil Change"
        case .tires:      return "Tires"
        case .brakes:     return "Brakes"
        case .service:    return "Service"
        case .repair:     return "Repair"
        case .battery:    return "Battery"
        case .inspection: return "Inspection"
        case .custom:     return "Other"
        }
    }
    var symbol: String {
        switch self {
        case .oil:        return "drop.fill"
        case .tires:      return "circle.circle.fill"
        case .brakes:     return "hexagon.fill"
        case .service:    return "wrench.and.screwdriver.fill"
        case .repair:     return "exclamationmark.triangle.fill"
        case .battery:    return "minus.plus.batteryblock.fill"
        case .inspection: return "checkmark.seal.fill"
        case .custom:     return "ellipsis.circle.fill"
        }
    }
    var tint: Color {
        switch self {
        case .oil:        return Theme.brand
        case .tires:      return Theme.ink
        case .brakes:     return Theme.red
        case .service:    return Theme.blue
        case .repair:     return Theme.amber
        case .battery:    return Theme.green
        case .inspection: return Theme.blue
        case .custom:     return Theme.ink2
        }
    }
}

// MARK: - Powertrain

enum Powertrain: String, CaseIterable, Codable, Identifiable {
    case gas, diesel, ev, phev
    var id: String { rawValue }
    var label: String {
        switch self {
        case .gas: return "Gas"; case .diesel: return "Diesel"
        case .ev: return "Electric"; case .phev: return "Plug-in Hybrid"
        }
    }
    var usesElectric: Bool { self == .ev || self == .phev }
    var usesLiquidFuel: Bool { self == .gas || self == .diesel || self == .phev }
}

enum EnergyKind: String, Codable { case gas, electric }
enum ChargeLocation: String, Codable, CaseIterable, Identifiable {
    case home, public_, other
    var id: String { rawValue }
    var label: String { self == .home ? "Home" : self == .public_ ? "Public" : "Other" }
}

// MARK: - Expense categories (non-service money events)

enum ExpenseCategory: String, CaseIterable, Codable, Identifiable {
    case insurance, registration, tax, wash, tolls, parking, loan, fine, accessory, fee, other
    var id: String { rawValue }
    var label: String {
        switch self {
        case .insurance: return "Insurance"; case .registration: return "Registration"
        case .tax: return "Tax"; case .wash: return "Car Wash"; case .tolls: return "Tolls"
        case .parking: return "Parking"; case .loan: return "Loan / Lease"; case .fine: return "Fine"
        case .accessory: return "Accessory"; case .fee: return "Fee"; case .other: return "Other"
        }
    }
    var symbol: String {
        switch self {
        case .insurance: return "shield.lefthalf.filled"; case .registration: return "doc.text.fill"
        case .tax: return "building.columns.fill"; case .wash: return "drop.degreesign.fill"
        case .tolls: return "road.lanes"; case .parking: return "parkingsign"
        case .loan: return "creditcard.fill"; case .fine: return "exclamationmark.octagon.fill"
        case .accessory: return "bag.fill"; case .fee: return "dollarsign.circle.fill"; case .other: return "ellipsis.circle.fill"
        }
    }
    var tint: Color {
        switch self {
        case .insurance: return Theme.blue; case .registration: return Theme.green
        case .tax: return Theme.ink; case .wash: return Theme.blue; case .tolls: return Theme.amber
        case .parking: return Theme.ink2; case .loan: return Theme.brand; case .fine: return Theme.red
        case .accessory: return Theme.green; case .fee: return Theme.amber; case .other: return Theme.ink2
        }
    }
    var isFixed: Bool { self == .insurance || self == .loan || self == .registration || self == .tax }
}

enum Recurrence: String, CaseIterable, Codable, Identifiable {
    case none, monthly, yearly
    var id: String { rawValue }
    var label: String { self == .none ? "One-time" : self == .monthly ? "Monthly" : "Yearly" }
    var months: Int? { self == .monthly ? 1 : self == .yearly ? 12 : nil }
}

// Spec pairs stored on a vehicle (filter #, tire size, PSI…).
struct SpecPair: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var label: String
    var value: String
}

// MARK: - Vehicle

@Model
final class Vehicle {
    var id: UUID = UUID()
    var name: String = ""
    var make: String = ""
    var modelName: String = ""
    var year: Int = 2024
    var colorHex: UInt = 0xF4631E
    var currentMileage: Int = 0
    var unit: String = "mi"            // "mi" or "km"
    var fuelUnit: String = "gal"       // "gal" or "L"
    var createdAt: Date = Date()

    var photoData: Data?               // optional vehicle photo
    var sortIndex: Int = 0
    var powertrainRaw: String = Powertrain.gas.rawValue
    var currencyCode: String = "USD"
    var isArchived: Bool = false
    var specPairs: [SpecPair] = []

    @Relationship(deleteRule: .cascade, inverse: \ServiceRecord.vehicle)
    var records: [ServiceRecord] = []
    @Relationship(deleteRule: .cascade, inverse: \FuelEntry.vehicle)
    var fuelEntries: [FuelEntry] = []
    @Relationship(deleteRule: .cascade, inverse: \Reminder.vehicle)
    var reminders: [Reminder] = []
    @Relationship(deleteRule: .cascade, inverse: \Expense.vehicle)
    var expenses: [Expense] = []
    @Relationship(deleteRule: .cascade, inverse: \EVReading.vehicle)
    var evReadings: [EVReading] = []
    @Relationship(deleteRule: .cascade, inverse: \Attachment.vehicle)
    var documents: [Attachment] = []

    init(name: String, make: String, modelName: String, year: Int,
         colorHex: UInt, currentMileage: Int, unit: String = "mi", fuelUnit: String = "gal",
         powertrain: Powertrain = .gas, currencyCode: String = "USD") {
        self.name = name
        self.make = make
        self.modelName = modelName
        self.year = year
        self.colorHex = colorHex
        self.currentMileage = currentMileage
        self.unit = unit
        self.fuelUnit = fuelUnit
        self.powertrainRaw = powertrain.rawValue
        self.currencyCode = currencyCode
    }

    var powertrain: Powertrain { Powertrain(rawValue: powertrainRaw) ?? .gas }
    var accent: Color { Color(hex: colorHex) }
    var subtitle: String {
        let parts = [year > 0 ? "\(year)" : nil, make.isEmpty ? nil : make, modelName.isEmpty ? nil : modelName]
            .compactMap { $0 }
        return parts.isEmpty ? "Vehicle" : parts.joined(separator: " · ")
    }
}

// MARK: - Service record

@Model
final class ServiceRecord {
    var id: UUID = UUID()
    var kindRaw: String = RecordKind.service.rawValue
    var title: String = ""
    var date: Date = Date()
    var mileage: Int = 0
    var cost: Double = 0
    var notes: String = ""
    var photoData: Data?               // legacy single photo (migrated to attachments)
    var currencyCode: String = "USD"
    var vehicle: Vehicle?
    @Relationship(deleteRule: .cascade, inverse: \Attachment.serviceRecord)
    var attachments: [Attachment] = []

    init(kind: RecordKind, title: String, date: Date, mileage: Int, cost: Double, notes: String = "", photoData: Data? = nil) {
        self.kindRaw = kind.rawValue
        self.title = title
        self.date = date
        self.mileage = mileage
        self.cost = cost
        self.notes = notes
        self.photoData = photoData
    }
    var kind: RecordKind { RecordKind(rawValue: kindRaw) ?? .custom }
}

// MARK: - Fuel entry

@Model
final class FuelEntry {
    var id: UUID = UUID()
    var date: Date = Date()
    var mileage: Int = 0
    var volume: Double = 0       // gallons or liters
    var cost: Double = 0
    var isFull: Bool = true
    var notes: String = ""
    var photoData: Data?
    var energyKindRaw: String = EnergyKind.gas.rawValue   // gas (volume=units) or electric (volume=kWh)
    var chargeLocationRaw: String?                        // home / public / other (electric only)
    var currencyCode: String = "USD"
    var vehicle: Vehicle?
    @Relationship(deleteRule: .cascade, inverse: \Attachment.fuelEntry)
    var attachments: [Attachment] = []

    init(date: Date, mileage: Int, volume: Double, cost: Double, isFull: Bool = true, notes: String = "",
         photoData: Data? = nil, energyKind: EnergyKind = .gas, chargeLocation: ChargeLocation? = nil) {
        self.date = date
        self.mileage = mileage
        self.volume = volume
        self.cost = cost
        self.isFull = isFull
        self.notes = notes
        self.photoData = photoData
        self.energyKindRaw = energyKind.rawValue
        self.chargeLocationRaw = chargeLocation?.rawValue
    }
    var energyKind: EnergyKind { EnergyKind(rawValue: energyKindRaw) ?? .gas }
    var isElectric: Bool { energyKind == .electric }
}

// MARK: - Reminder (date-based OR mileage-based)

@Model
final class Reminder {
    var id: UUID = UUID()
    var kindRaw: String = RecordKind.oil.rawValue
    var title: String = ""
    var dueDate: Date?
    var dueMileage: Int?
    var intervalMonths: Int?
    var intervalMiles: Int?
    var isEnabled: Bool = true
    var notify: Bool = true            // schedule a local notification for date-based reminders
    var notificationID: String = UUID().uuidString
    // Completion-loop fields
    var leadMiles: Int = 200
    var leadDays: Int = 14
    var anchorMileage: Int?
    var anchorDate: Date?
    var linkedKindRaw: String?         // which logged service type completes this (default = kind)
    var snoozedUntil: Date?
    var vehicle: Vehicle?

    init(kind: RecordKind, title: String, dueDate: Date? = nil, dueMileage: Int? = nil,
         intervalMonths: Int? = nil, intervalMiles: Int? = nil, notify: Bool = true) {
        self.kindRaw = kind.rawValue
        self.title = title
        self.dueDate = dueDate
        self.dueMileage = dueMileage
        self.intervalMonths = intervalMonths
        self.intervalMiles = intervalMiles
        self.notify = notify
    }
    var kind: RecordKind { RecordKind(rawValue: kindRaw) ?? .custom }
    var linkedKind: RecordKind { linkedKindRaw.flatMap { RecordKind(rawValue: $0) } ?? kind }
    var isRecurring: Bool { intervalMiles != nil || intervalMonths != nil }
}

// MARK: - Expense (non-service money event)

@Model
final class Expense {
    var id: UUID = UUID()
    var categoryRaw: String = ExpenseCategory.other.rawValue
    var amount: Double = 0
    var currencyCode: String = "USD"
    var date: Date = Date()
    var mileage: Int?
    var note: String = ""
    var recurrenceRaw: String = Recurrence.none.rawValue
    var vehicle: Vehicle?
    @Relationship(deleteRule: .cascade, inverse: \Attachment.expense)
    var attachments: [Attachment] = []

    init(category: ExpenseCategory, amount: Double, date: Date, mileage: Int? = nil,
         note: String = "", recurrence: Recurrence = .none, currencyCode: String = "USD") {
        self.categoryRaw = category.rawValue
        self.amount = amount
        self.date = date
        self.mileage = mileage
        self.note = note
        self.recurrenceRaw = recurrence.rawValue
        self.currencyCode = currencyCode
    }
    var category: ExpenseCategory { ExpenseCategory(rawValue: categoryRaw) ?? .other }
    var recurrence: Recurrence { Recurrence(rawValue: recurrenceRaw) ?? .none }
}

// MARK: - Attachment (photo or document; belongs to exactly one owner)

@Model
final class Attachment {
    var id: UUID = UUID()
    var kindRaw: String = "photo"      // photo / document
    var filename: String = ""
    var data: Data = Data()
    var createdAt: Date = Date()
    var expiryDate: Date?              // for glovebox documents (registration/insurance)
    // owners (exactly one set)
    var vehicle: Vehicle?
    var serviceRecord: ServiceRecord?
    var fuelEntry: FuelEntry?
    var expense: Expense?

    init(kind: String = "photo", filename: String = "", data: Data, expiryDate: Date? = nil) {
        self.kindRaw = kind
        self.filename = filename
        self.data = data
        self.expiryDate = expiryDate
    }
    var isDocument: Bool { kindRaw == "document" }
}

// MARK: - EV reading (range / state-of-health over time)

@Model
final class EVReading {
    var id: UUID = UUID()
    var date: Date = Date()
    var mileage: Int = 0
    var estRangeMiles: Int?
    var sohPercent: Double?
    var vehicle: Vehicle?

    init(date: Date, mileage: Int, estRangeMiles: Int? = nil, sohPercent: Double? = nil) {
        self.date = date
        self.mileage = mileage
        self.estRangeMiles = estRangeMiles
        self.sohPercent = sohPercent
    }
}

// MARK: - Service template (Pro) — reusable maintenance schedule

@Model
final class ServiceTemplate {
    var id: UUID = UUID()
    var kindRaw: String = RecordKind.oil.rawValue
    var title: String = ""
    var intervalMiles: Int?
    var intervalMonths: Int?
    var createdAt: Date = Date()

    init(kind: RecordKind, title: String, intervalMiles: Int? = nil, intervalMonths: Int? = nil) {
        self.kindRaw = kind.rawValue
        self.title = title
        self.intervalMiles = intervalMiles
        self.intervalMonths = intervalMonths
    }
    var kind: RecordKind { RecordKind(rawValue: kindRaw) ?? .custom }

    var intervalText: String {
        var parts: [String] = []
        if let m = intervalMiles { parts.append("\(m.milesGrouped) mi") }
        if let mo = intervalMonths { parts.append("\(mo) mo") }
        return parts.isEmpty ? "No interval" : "Every " + parts.joined(separator: " / ")
    }
}

// Built-in templates (code constants — always available, never CloudKit-duplicated).
struct BuiltInTemplate: Identifiable {
    let id = UUID()
    let kind: RecordKind
    let title: String
    let intervalMiles: Int?
    let intervalMonths: Int?
    var intervalText: String {
        var parts: [String] = []
        if let m = intervalMiles { parts.append("\(m.milesGrouped) mi") }
        if let mo = intervalMonths { parts.append("\(mo) mo") }
        return parts.isEmpty ? "No interval" : "Every " + parts.joined(separator: " / ")
    }

    static let all: [BuiltInTemplate] = [
        BuiltInTemplate(kind: .oil, title: "Oil & filter change", intervalMiles: 5_000, intervalMonths: 6),
        BuiltInTemplate(kind: .tires, title: "Tire rotation", intervalMiles: 6_000, intervalMonths: nil),
        BuiltInTemplate(kind: .service, title: "Air filter", intervalMiles: 12_000, intervalMonths: nil),
        BuiltInTemplate(kind: .brakes, title: "Brake inspection", intervalMiles: 12_000, intervalMonths: 12),
        BuiltInTemplate(kind: .battery, title: "Battery check", intervalMiles: nil, intervalMonths: 12),
        BuiltInTemplate(kind: .inspection, title: "Registration / inspection", intervalMiles: nil, intervalMonths: 12),
        BuiltInTemplate(kind: .service, title: "Coolant flush", intervalMiles: 30_000, intervalMonths: 24),
        BuiltInTemplate(kind: .tires, title: "Wheel alignment", intervalMiles: 20_000, intervalMonths: nil),
    ]
}
