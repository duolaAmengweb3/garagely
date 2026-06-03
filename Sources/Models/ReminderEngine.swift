import Foundation

// The completion-loop engine. 100% local: estimates how fast a vehicle is driven
// from its own odometer history, projects a mileage-due into a calendar date so a
// real notification can fire, and rolls a reminder forward when a service is logged.

extension Vehicle {
    /// All timestamped odometer readings, from any record type, de-noised to be monotonic.
    var odometerPoints: [(date: Date, mileage: Int)] {
        var raw: [(Date, Int)] = []
        raw += records.map { ($0.date, $0.mileage) }
        raw += fuelEntries.map { ($0.date, $0.mileage) }
        raw += expenses.compactMap { e in e.mileage.map { (e.date, $0) } }
        raw += evReadings.map { ($0.date, $0.mileage) }
        let sorted = raw.filter { $0.1 > 0 }.sorted { $0.0 < $1.0 }
        // keep only non-decreasing mileage (drop obviously-wrong points)
        var cleaned: [(Date, Int)] = []
        for p in sorted where cleaned.last == nil || p.1 >= cleaned.last!.1 {
            cleaned.append(p)
        }
        return cleaned.map { (date: $0.0, mileage: $0.1) }
    }

    /// Robust average miles driven per day, with a sane fallback (~11k mi/yr).
    var milesPerDay: Double {
        let pts = odometerPoints
        guard let first = pts.first, let last = pts.last, pts.count >= 2 else { return 30 }
        let days = Calendar.current.dateComponents([.day], from: first.date, to: last.date).day ?? 0
        let miles = last.mileage - first.mileage
        guard days >= 14, miles > 0 else { return 30 }
        return Double(miles) / Double(days)
    }

    /// Predicted calendar date the odometer will reach `target`, anchored at today's odometer.
    func predictedDate(forMileage target: Int) -> Date? {
        let remaining = target - currentMileage
        if remaining <= 0 { return Date() }
        let days = Double(remaining) / max(milesPerDay, 1)
        return Calendar.current.date(byAdding: .day, value: Int(days.rounded()), to: Date())
    }
}

extension Reminder {
    /// Prediction-aware urgency: a mileage reminder also becomes "due soon" by its
    /// projected date, and shows an estimated time alongside the remaining distance.
    func liveDue(in vehicle: Vehicle) -> DueInfo {
        var best: DueInfo?
        func consider(_ i: DueInfo) { if best == nil || i.sortKey < best!.sortKey { best = i } }

        if let dm = dueMileage {
            let remaining = dm - vehicle.currentMileage
            let predicted = vehicle.predictedDate(forMileage: dm)
            let daysOut = predicted.map { Calendar.current.dateComponents([.day], from: Date(), to: $0).day ?? 0 }
            let status: ServiceStatus
            if remaining <= 0 { status = .overdue }
            else if remaining <= leadMiles || (daysOut ?? .max) <= leadDays { status = .dueSoon }
            else { status = .healthy }
            var headline = remaining <= 0 ? "\(abs(remaining).milesGrouped) \(vehicle.unit) over"
                                          : "in \(remaining.milesGrouped) \(vehicle.unit)"
            if let d = daysOut, d > 0, remaining > 0 { headline += " · ~\(relativeDays(d))" }
            consider(DueInfo(status: status, headline: headline, sortKey: Double(remaining)))
        }
        if let dd = dueDate {
            let days = Calendar.current.dateComponents([.day], from: Date(), to: dd).day ?? 0
            let status: ServiceStatus = days < 0 ? .overdue : (days <= leadDays ? .dueSoon : .healthy)
            let headline = days < 0 ? "\(relative(dd)) over" : "in \(relative(dd))"
            consider(DueInfo(status: status, headline: headline, sortKey: Double(days) * 30))
        }
        return best ?? DueInfo(status: .healthy, headline: "—", sortKey: .greatestFiniteMagnitude)
    }

    /// When the local notification should fire (earliest of the date/mileage paths, minus lead). Nil if not schedulable.
    func fireDate(in vehicle: Vehicle) -> Date? {
        guard isEnabled, notify else { return nil }
        var candidates: [Date] = []
        if let dd = dueDate {
            candidates.append(Calendar.current.date(byAdding: .day, value: -leadDays, to: dd) ?? dd)
        }
        if let dm = dueMileage, let predicted = vehicle.predictedDate(forMileage: dm) {
            candidates.append(Calendar.current.date(byAdding: .day, value: -leadDays, to: predicted) ?? predicted)
        }
        if let snooze = snoozedUntil { candidates = candidates.map { max($0, snooze) } }
        guard let earliest = candidates.min() else { return nil }
        return earliest > Date() ? earliest : nil   // overdue items already surface in-app
    }

    /// Roll the schedule forward from the point the work was actually done.
    func complete(loggedMileage: Int, loggedDate: Date) {
        anchorMileage = loggedMileage
        anchorDate = loggedDate
        if let im = intervalMiles { dueMileage = loggedMileage + im }
        if let imo = intervalMonths { dueDate = Calendar.current.date(byAdding: .month, value: imo, to: loggedDate) }
        snoozedUntil = nil
    }

    /// Does logging `kind` at `mileage` plausibly satisfy this reminder?
    func matches(kind: RecordKind) -> Bool { isEnabled && isRecurring && linkedKind == kind }

    private func relative(_ date: Date) -> String {
        let days = abs(Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0)
        return relativeDays(days)
    }
    private func relativeDays(_ days: Int) -> String {
        if days >= 14 { return "\(days / 7) weeks" }
        if days >= 7  { return "1 week" }
        if days <= 1  { return "1 day" }
        return "\(days) days"
    }
}
