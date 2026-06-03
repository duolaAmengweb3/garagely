import Foundation
import SwiftData

// Deterministic in-process audit of the core logic + managers.
// Run with: SIMCTL_CHILD_SELFTEST=1 ... and read the console.
enum SelfTest {
    @MainActor
    static func run() {
        var pass = 0, fail = 0
        var lines: [String] = []
        func check(_ name: String, _ cond: Bool) {
            let mark = cond ? "PASS" : "FAIL"
            if cond { pass += 1 } else { fail += 1 }
            let line = "[\(mark)] \(name)"
            lines.append(line)
            NSLog("SELFTEST \(line)")
        }
        defer {
            let summary = "SELFTEST RESULT: \(pass)/\(pass + fail)"
            lines.append(summary); NSLog(summary)
            let text = lines.joined(separator: "\n")
            if let dir = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.id) {
                try? text.write(to: dir.appendingPathComponent("selftest.txt"), atomically: true, encoding: .utf8)
            }
        }

        // In-memory store so we never touch the user's data.
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        guard let container = try? ModelContainer(for: Vehicle.self, ServiceRecord.self, FuelEntry.self, Reminder.self, ServiceTemplate.self, Expense.self, Attachment.self, EVReading.self, configurations: config) else {
            print("❌ container"); print("SELFTEST RESULT: 0/1"); return
        }
        let ctx = container.mainContext
        let cal = Calendar.current
        func daysAgo(_ d: Int) -> Date { cal.date(byAdding: .day, value: -d, to: Date())! }

        // Build a vehicle with records, fuel and reminders.
        let v = Vehicle(name: "Test Car", make: "Honda", modelName: "Civic", year: 2021, colorHex: 0xED5B22, currentMileage: 50_000)
        ctx.insert(v)
        let r1 = ServiceRecord(kind: .oil, title: "Oil", date: daysAgo(30), mileage: 48_000, cost: 60); r1.vehicle = v
        let r2 = ServiceRecord(kind: .brakes, title: "Brakes", date: daysAgo(10), mileage: 49_500, cost: 200); r2.vehicle = v
        ctx.insert(r1); ctx.insert(r2)
        let f1 = FuelEntry(date: daysAgo(20), mileage: 49_000, volume: 10, cost: 40, isFull: true); f1.vehicle = v
        let f2 = FuelEntry(date: daysAgo(5),  mileage: 49_300, volume: 10, cost: 40, isFull: true); f2.vehicle = v
        ctx.insert(f1); ctx.insert(f2)
        let remOverdue = Reminder(kind: .tires, title: "Tires", dueMileage: 49_800); remOverdue.vehicle = v   // 200 over
        let remFuture  = Reminder(kind: .oil, title: "Oil", dueMileage: 53_000); remFuture.vehicle = v          // 3000 out
        ctx.insert(remOverdue); ctx.insert(remFuture)
        try? ctx.save()

        // 1. totals
        check("totalSpend = 340", v.totalSpend == 340)
        // 2. economy: 300 miles / 10 gal = 30 MPG
        check("averageEconomy = 30", v.averageEconomy.map { abs($0 - 30) < 0.01 } ?? false)
        // 3. nextDue picks the overdue tires
        check("nextDue is overdue tires", v.nextDue?.reminder.title == "Tires" && v.nextDue?.info.status == .overdue)
        // 4. due headline for overdue mileage
        check("overdue headline mentions over", v.nextDue?.info.headline.contains("over") ?? false)
        // 5. future reminder is healthy
        let futureInfo = remFuture.due(currentMileage: v.currentMileage, unit: v.unit)
        check("future reminder healthy", futureInfo.status == .healthy)

        // 6. CSV export
        if let url = ExportManager.csv(for: v), let s = try? String(contentsOf: url, encoding: .utf8) {
            check("CSV has header + rows", s.contains("Date,Record Type") && s.contains("Oil") && s.contains("Fuel"))
        } else { check("CSV export", false) }
        // 7. PDF export
        if let url = ExportManager.pdf(for: v), let data = try? Data(contentsOf: url) {
            check("PDF non-empty", data.count > 1000)
        } else { check("PDF export", false) }

        // 8. App Group snapshot round-trip
        SnapshotWriter.write(vehicles: [v])
        if let snap = GarageSnapshot.load() {
            check("snapshot round-trips vehicle", snap.vehicles.contains { $0.name == "Test Car" })
            check("snapshot status overdue", snap.vehicles.first { $0.name == "Test Car" }?.statusRaw == 2)
        } else { check("snapshot App Group write/read", false) }

        // 9. soft odometer / back-dating: adding an older, lower-mileage record must not lower currentMileage
        let old = ServiceRecord(kind: .service, title: "Old service", date: daysAgo(400), mileage: 30_000, cost: 10); old.vehicle = v
        ctx.insert(old); try? ctx.save()
        check("back-dated record keeps odometer", v.currentMileage == 50_000)

        // 10. applying a built-in template creates a correctly-scheduled reminder
        let tpl = BuiltInTemplate.all.first { $0.intervalMiles != nil }!
        let applied = Reminder(kind: tpl.kind, title: tpl.title, intervalMiles: tpl.intervalMiles)
        applied.dueMileage = v.currentMileage + (tpl.intervalMiles ?? 0)
        applied.vehicle = v; ctx.insert(applied); try? ctx.save()
        check("template apply schedules reminder", applied.dueMileage == 50_000 + tpl.intervalMiles!)

        // 11. custom template persists
        let ct = ServiceTemplate(kind: .custom, title: "Detailing", intervalMonths: 3)
        ctx.insert(ct); try? ctx.save()
        let templates = (try? ctx.fetch(FetchDescriptor<ServiceTemplate>())) ?? []
        check("custom template persists", templates.contains { $0.title == "Detailing" })

        // ── v2: TCO, EV, completion loop, expenses, attachments ───────────
        // 12. expense adds to TCO
        let preTCO = v.totalSpend
        let exp = Expense(category: .insurance, amount: 100, date: daysAgo(5)); exp.vehicle = v
        ctx.insert(exp); try? ctx.save()
        check("expense folds into TCO", abs(v.totalSpend - (preTCO + 100)) < 0.01)

        // 13. EV charging economy = mi/kWh
        let ev = Vehicle(name: "EV", make: "Tesla", modelName: "3", year: 2023, colorHex: 0x3B7DD8, currentMileage: 1000, powertrain: .ev)
        ctx.insert(ev)
        let c1 = FuelEntry(date: daysAgo(10), mileage: 500, volume: 40, cost: 5, isFull: true, energyKind: .electric); c1.vehicle = ev
        let c2 = FuelEntry(date: daysAgo(2), mileage: 1000, volume: 125, cost: 16, isFull: true, energyKind: .electric); c2.vehicle = ev
        ctx.insert(c1); ctx.insert(c2); try? ctx.save()
        check("EV economy = 4 mi/kWh", ev.electricEconomy.map { abs($0 - 4) < 0.01 } ?? false)
        check("EV has no liquid economy", ev.averageEconomy == nil)

        // 14. mileage rate + prediction
        check("milesPerDay > 0", v.milesPerDay > 0)
        check("predicted date is in the future", v.predictedDate(forMileage: v.currentMileage + 5000).map { $0 > Date() } ?? false)

        // 15. completion loop rolls the schedule forward
        let loop = Reminder(kind: .oil, title: "Oil", dueMileage: 51_000, intervalMiles: 5_000); loop.vehicle = v
        ctx.insert(loop); try? ctx.save()
        loop.complete(loggedMileage: 50_000, loggedDate: Date())
        check("completion advances dueMileage to 55,000", loop.dueMileage == 55_000)
        check("matching reminder detects service kind", loop.matches(kind: .oil))

        // 16. attachment belongs to a record
        let att = Attachment(kind: "photo", filename: "r.jpg", data: Data([1,2,3])); att.serviceRecord = r1
        ctx.insert(att); try? ctx.save()
        check("attachment linked to record", r1.attachments.contains { $0.id == att.id })

        // 17. CSV includes expense + recordType column
        if let url = ExportManager.csv(for: v), let s = try? String(contentsOf: url, encoding: .utf8) {
            check("CSV has recordType + expense", s.contains("Record Type") && s.contains("Insurance"))
        } else { check("CSV v2", false) }

        print("SELFTEST RESULT: \(pass)/\(pass + fail)")
    }
}
