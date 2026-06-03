import Foundation
import SwiftData

enum SeedData {
    static func populateIfNeeded(_ context: ModelContext) {
        let count = (try? context.fetchCount(FetchDescriptor<Vehicle>())) ?? 0
        guard count == 0 else { return }

        let cal = Calendar.current
        func daysAgo(_ d: Int) -> Date { cal.date(byAdding: .day, value: -d, to: Date())! }
        func daysAhead(_ d: Int) -> Date { cal.date(byAdding: .day, value: d, to: Date())! }

        // ── Vehicle 1: Honda Civic — healthy ───────────────────────────────
        let civic = Vehicle(name: "Honda Civic", make: "Honda", modelName: "Civic",
                            year: 2021, colorHex: 0xF4631E, currentMileage: 42_300)
        context.insert(civic)
        civic.records = [
            ServiceRecord(kind: .oil,    title: "Oil & filter change", date: daysAgo(48),  mileage: 41_480, cost: 62, notes: "Mobil 1 full synthetic"),
            ServiceRecord(kind: .tires,  title: "Tire rotation",       date: daysAgo(48),  mileage: 41_480, cost: 25),
            ServiceRecord(kind: .brakes, title: "Front brake pads",    date: daysAgo(190), mileage: 38_900, cost: 240),
            ServiceRecord(kind: .inspection, title: "State inspection", date: daysAgo(210), mileage: 38_400, cost: 35),
        ]
        civic.fuelEntries = [
            FuelEntry(date: daysAgo(38), mileage: 41_640, volume: 11.2, cost: 41.8),
            FuelEntry(date: daysAgo(26), mileage: 41_980, volume: 10.6, cost: 39.2),
            FuelEntry(date: daysAgo(14), mileage: 42_010, volume: 9.4,  cost: 35.1),
            FuelEntry(date: daysAgo(4),  mileage: 42_300, volume: 11.0, cost: 41.0),
        ]
        civic.reminders = [
            Reminder(kind: .oil,   title: "Oil change",     dueMileage: 46_480, intervalMiles: 5_000),
            Reminder(kind: .tires, title: "Tire rotation",  dueMileage: 47_480, intervalMiles: 6_000),
            Reminder(kind: .inspection, title: "State inspection", dueDate: daysAhead(120), intervalMonths: 12),
        ]

        // ── Vehicle 2: Toyota RAV4 — has an overdue item ───────────────────
        let rav4 = Vehicle(name: "Toyota RAV4", make: "Toyota", modelName: "RAV4",
                           year: 2019, colorHex: 0x2E6F73, currentMileage: 68_900)
        context.insert(rav4)
        rav4.records = [
            ServiceRecord(kind: .oil,     title: "Oil & filter change", date: daysAgo(120), mileage: 64_100, cost: 58),
            ServiceRecord(kind: .battery, title: "Battery replacement", date: daysAgo(75),  mileage: 66_200, cost: 180),
            ServiceRecord(kind: .service, title: "60k major service",   date: daysAgo(60),  mileage: 66_900, cost: 420, notes: "Plugs, coolant, transmission fluid"),
        ]
        rav4.fuelEntries = [
            FuelEntry(date: daysAgo(20), mileage: 68_400, volume: 13.8, cost: 51.0),
            FuelEntry(date: daysAgo(6),  mileage: 68_900, volume: 12.9, cost: 47.7),
        ]
        rav4.reminders = [
            Reminder(kind: .brakes, title: "Brake inspection", dueMileage: 68_500, intervalMiles: 12_000),  // overdue (400 mi over)
            Reminder(kind: .oil,    title: "Oil change",       dueMileage: 69_100, intervalMiles: 5_000),    // due soon
        ]
        civic.expenses = [
            Expense(category: .insurance, amount: 92, date: daysAgo(20), note: "Monthly premium", recurrence: .monthly),
            Expense(category: .registration, amount: 85, date: daysAgo(60), recurrence: .yearly),
            Expense(category: .wash, amount: 15, date: daysAgo(8)),
        ]
        civic.specPairs = [
            SpecPair(label: "Oil filter", value: "Fram PH7317"),
            SpecPair(label: "Tire size", value: "215/55R16"),
            SpecPair(label: "Tire PSI", value: "33 front / 32 rear"),
            SpecPair(label: "Battery group", value: "51R"),
        ]

        // ── Vehicle 3: Tesla Model 3 — EV ──────────────────────────────────
        let tesla = Vehicle(name: "Tesla Model 3", make: "Tesla", modelName: "Model 3",
                            year: 2023, colorHex: 0x3B7DD8, currentMileage: 18_400,
                            powertrain: .ev)
        context.insert(tesla)
        tesla.records = [
            ServiceRecord(kind: .tires, title: "Tire rotation", date: daysAgo(40), mileage: 16_000, cost: 60),
        ]
        tesla.fuelEntries = [
            FuelEntry(date: daysAgo(24), mileage: 17_200, volume: 48, cost: 6.2,  isFull: true, energyKind: .electric, chargeLocation: .home),
            FuelEntry(date: daysAgo(12), mileage: 17_800, volume: 52, cost: 14.0, isFull: true, energyKind: .electric, chargeLocation: .public_),
            FuelEntry(date: daysAgo(3),  mileage: 18_400, volume: 50, cost: 6.5,  isFull: true, energyKind: .electric, chargeLocation: .home),
        ]
        tesla.reminders = [
            Reminder(kind: .tires, title: "Tire rotation", dueMileage: 22_000, intervalMiles: 6_000),
            Reminder(kind: .service, title: "Brake fluid", dueMileage: 36_000, intervalMiles: 20_000),
        ]
        tesla.expenses = [
            Expense(category: .insurance, amount: 110, date: daysAgo(15), recurrence: .monthly),
        ]
        tesla.evReadings = [
            EVReading(date: daysAgo(60), mileage: 14_000, estRangeMiles: 272, sohPercent: 98),
            EVReading(date: daysAgo(10), mileage: 18_000, estRangeMiles: 265, sohPercent: 96),
        ]

        try? context.save()
    }
}
