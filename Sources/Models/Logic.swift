import Foundation

// MARK: - Due computation for a single reminder

struct DueInfo {
    var status: ServiceStatus
    var headline: String     // e.g. "in 820 mi"  /  "in 12 days"  /  "2 weeks over"
    var sortKey: Double      // smaller = more urgent
}

extension Reminder {
    /// Thresholds: due-soon when within 500 mi or 21 days.
    func due(currentMileage: Int, unit: String) -> DueInfo {
        var best: DueInfo?

        func consider(_ info: DueInfo) {
            if best == nil || info.sortKey < best!.sortKey { best = info }
        }

        if let dm = dueMileage {
            let remaining = dm - currentMileage
            let status: ServiceStatus = remaining <= 0 ? .overdue : (remaining <= 500 ? .dueSoon : .healthy)
            let headline = remaining <= 0
                ? "\(abs(remaining).milesGrouped) \(unit) over"
                : "in \(remaining.milesGrouped) \(unit)"
            consider(DueInfo(status: status, headline: headline, sortKey: Double(remaining)))
        }
        if let dd = dueDate {
            let days = Calendar.current.dateComponents([.day], from: Date(), to: dd).day ?? 0
            let status: ServiceStatus = days < 0 ? .overdue : (days <= 21 ? .dueSoon : .healthy)
            let headline = days < 0 ? "\(relative(dd)) over" : "in \(relative(dd))"
            // weight days so a tie-break with mileage stays comparable (≈ miles/day)
            consider(DueInfo(status: status, headline: headline, sortKey: Double(days) * 30))
        }
        return best ?? DueInfo(status: .healthy, headline: "—", sortKey: .greatestFiniteMagnitude)
    }

    private func relative(_ date: Date) -> String {
        let days = abs(Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0)
        if days >= 14 { return "\(days / 7) weeks" }
        if days >= 7  { return "1 week" }
        if days <= 1  { return "1 day" }
        return "\(days) days"
    }
}

// MARK: - Vehicle roll-ups

extension Vehicle {
    /// The single most urgent reminder, surfaced on the garage card (prediction-aware).
    var nextDue: (reminder: Reminder, info: DueInfo)? {
        let active = reminders.filter { $0.isEnabled }
        let evaluated = active.map { ($0, $0.liveDue(in: self)) }
        return evaluated.min { $0.1.sortKey < $1.1.sortKey }.map { ($0.0, $0.1) }
    }

    /// Total cost of ownership: service + fuel + charging + non-service expenses.
    var totalSpend: Double {
        records.reduce(0) { $0 + $1.cost }
        + fuelEntries.reduce(0) { $0 + $1.cost }
        + expenses.reduce(0) { $0 + $1.amount }
    }

    private func economy(electric: Bool) -> Double? {
        let fills = fuelEntries.filter { $0.isFull && $0.isElectric == electric }.sorted { $0.mileage < $1.mileage }
        guard fills.count >= 2 else { return nil }
        var miles = 0, units = 0.0
        for i in 1..<fills.count {
            miles += fills[i].mileage - fills[i - 1].mileage
            units += fills[i].volume
        }
        guard units > 0 else { return nil }
        return Double(miles) / units
    }

    /// Liquid-fuel economy (MPG / km·L). Nil for pure EVs.
    var averageEconomy: Double? { economy(electric: false) }
    /// Electric economy (mi/kWh). Nil unless charging logged.
    var electricEconomy: Double? { economy(electric: true) }

    var economyUnit: String { fuelUnit == "gal" ? "MPG" : "km/L" }
    var electricEconomyUnit: String { "mi/kWh" }
}

// MARK: - Formatting helpers

extension Int {
    var milesGrouped: String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

extension Double {
    var currency: String { currency(code: "USD") }
    func currency(code: String) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = code
        f.maximumFractionDigits = (self.truncatingRemainder(dividingBy: 1) == 0) ? 0 : 2
        return f.string(from: NSNumber(value: self)) ?? "\(code) \(self)"
    }
}

// Common currencies for the picker.
enum Currencies {
    static let codes = ["USD", "EUR", "GBP", "JPY", "CNY", "CAD", "AUD", "BRL", "INR", "MXN", "CHF", "SEK"]
    static func symbol(_ code: String) -> String {
        let f = NumberFormatter(); f.numberStyle = .currency; f.currencyCode = code
        return f.currencySymbol ?? code
    }
}

extension Date {
    var shortLabel: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: self)
    }
    var monthDay: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: self)
    }
}
