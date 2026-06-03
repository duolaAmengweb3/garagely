import Foundation
import UIKit
import PDFKit

enum ExportManager {

    // MARK: CSV

    static func csv(for vehicle: Vehicle) -> URL? {
        var rows: [String] = ["Date,Record Type,Category,Detail,Odometer (\(vehicle.unit)),Amount (\(vehicle.currencyCode)),Notes"]
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"

        struct Line { let date: Date; let recordType: String; let category: String; let detail: String; let mileage: Int?; let amount: Double; let notes: String }
        var lines: [Line] = []
        lines += vehicle.records.map { Line(date: $0.date, recordType: "Service", category: $0.kind.label, detail: $0.title, mileage: $0.mileage, amount: $0.cost, notes: $0.notes) }
        lines += vehicle.fuelEntries.map { f in
            Line(date: f.date, recordType: f.isElectric ? "Charge" : "Fuel", category: f.isElectric ? "Charging" : "Fuel",
                 detail: String(format: "%.1f %@", f.volume, f.isElectric ? "kWh" : vehicle.fuelUnit), mileage: f.mileage, amount: f.cost, notes: f.notes)
        }
        lines += vehicle.expenses.map { Line(date: $0.date, recordType: "Expense", category: $0.category.label, detail: $0.recurrence == .none ? "" : $0.recurrence.label, mileage: $0.mileage, amount: $0.amount, notes: $0.note) }
        lines.sort { $0.date > $1.date }

        for l in lines {
            rows.append(csvRow([df.string(from: l.date), l.recordType, l.category, l.detail,
                                l.mileage.map { "\($0)" } ?? "", String(format: "%.2f", l.amount), l.notes]))
        }
        return write(rows.joined(separator: "\n"), name: "\(safeName(vehicle.name))-records.csv")
    }

    private static func csvRow(_ fields: [String]) -> String {
        fields.map { field in
            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }.joined(separator: ",")
    }

    // MARK: PDF

    static func pdf(for vehicle: Vehicle) -> URL? {
        let pageW: CGFloat = 612, pageH: CGFloat = 792, margin: CGFloat = 48
        let format = UIGraphicsPDFRendererFormat()
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageW, height: pageH), format: format)

        let df = DateFormatter(); df.dateFormat = "MMM d, yyyy"
        let orange = UIColor(red: 0.93, green: 0.36, blue: 0.13, alpha: 1)
        let ink = UIColor(red: 0.13, green: 0.14, blue: 0.13, alpha: 1)
        let gray = UIColor(red: 0.41, green: 0.42, blue: 0.40, alpha: 1)

        struct Line { let date: Date; let type: String; let title: String; let mileage: Int; let cost: Double }
        var lines: [Line] = vehicle.records.map { Line(date: $0.date, type: $0.kind.label, title: $0.title, mileage: $0.mileage, cost: $0.cost) }
        lines += vehicle.fuelEntries.map { Line(date: $0.date, type: $0.isElectric ? "Charge" : "Fuel", title: String(format: "%.1f %@", $0.volume, $0.isElectric ? "kWh" : vehicle.fuelUnit), mileage: $0.mileage, cost: $0.cost) }
        lines += vehicle.expenses.map { Line(date: $0.date, type: $0.category.label, title: $0.note.isEmpty ? "Expense" : $0.note, mileage: $0.mileage ?? 0, cost: $0.amount) }
        lines.sort { $0.date > $1.date }
        let total = lines.reduce(0) { $0 + $1.cost }

        let url = tempURL("\(safeName(vehicle.name))-history.pdf")
        do {
            try renderer.writePDF(to: url) { ctx in
                ctx.beginPage()
                var y: CGFloat = margin

                draw("Garagely", at: CGPoint(x: margin, y: y), font: .systemFont(ofSize: 13, weight: .bold), color: orange)
                y += 28
                draw(vehicle.name, at: CGPoint(x: margin, y: y), font: .systemFont(ofSize: 26, weight: .bold), color: ink)
                y += 32
                draw("\(vehicle.subtitle) · \(vehicle.currentMileage.milesGrouped) \(vehicle.unit)",
                     at: CGPoint(x: margin, y: y), font: .systemFont(ofSize: 13, weight: .medium), color: gray)
                y += 20
                draw("Total spend \(total.currency(code: vehicle.currencyCode)) · \(lines.count) records",
                     at: CGPoint(x: margin, y: y), font: .systemFont(ofSize: 13, weight: .semibold), color: ink)
                y += 34

                // header row
                drawColumns(["DATE", "TYPE", "DETAIL", "ODO", "COST"], y: y, font: .systemFont(ofSize: 10, weight: .bold), color: gray, margin: margin, width: pageW - margin * 2)
                y += 18
                drawHairline(y: y, margin: margin, width: pageW - margin * 2)
                y += 10

                for line in lines {
                    if y > pageH - margin {
                        ctx.beginPage(); y = margin
                    }
                    drawColumns([df.string(from: line.date), line.type, String(line.title.prefix(28)),
                                 line.mileage.milesGrouped, line.cost.currency(code: vehicle.currencyCode)],
                                y: y, font: .systemFont(ofSize: 11, weight: .regular), color: ink, margin: margin, width: pageW - margin * 2)
                    y += 22
                }
            }
            return url
        } catch { return nil }
    }

    private static func drawColumns(_ cols: [String], y: CGFloat, font: UIFont, color: UIColor, margin: CGFloat, width: CGFloat) {
        let xs: [CGFloat] = [0, 0.22, 0.40, 0.74, 0.88].map { margin + $0 * width }
        for (i, c) in cols.enumerated() {
            draw(c, at: CGPoint(x: xs[i], y: y), font: font, color: color)
        }
    }

    private static func drawHairline(y: CGFloat, margin: CGFloat, width: CGFloat) {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: margin, y: y))
        path.addLine(to: CGPoint(x: margin + width, y: y))
        UIColor(white: 0.85, alpha: 1).setStroke()
        path.lineWidth = 0.5
        path.stroke()
    }

    private static func draw(_ text: String, at point: CGPoint, font: UIFont, color: UIColor) {
        (text as NSString).draw(at: point, withAttributes: [.font: font, .foregroundColor: color])
    }

    // MARK: helpers

    private static func safeName(_ s: String) -> String {
        s.components(separatedBy: CharacterSet.alphanumerics.inverted).joined(separator: "-")
    }
    private static func tempURL(_ name: String) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(name)
    }
    private static func write(_ content: String, name: String) -> URL? {
        let url = tempURL(name)
        do { try content.write(to: url, atomically: true, encoding: .utf8); return url }
        catch { return nil }
    }
}
