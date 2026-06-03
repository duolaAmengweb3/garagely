import AppKit

let W = 1320.0, H = 2868.0
let paper = NSColor(srgbRed: 0xF4/255, green: 0xF1/255, blue: 0xEB/255, alpha: 1)
let ink   = NSColor(srgbRed: 0x20/255, green: 0x23/255, blue: 0x21/255, alpha: 1)
let mid   = NSColor(srgbRed: 0x69/255, green: 0x6B/255, blue: 0x66/255, alpha: 1)
let orange = NSColor(srgbRed: 0xED/255, green: 0x5B/255, blue: 0x22/255, alpha: 1)

let dir = "/Users/duolaameng/Desktop/applestore/15_Garagely/brand"

struct Poster { let shot: String; let out: String; let head: String; let sub: String }
// Order = strongest download hooks first (search shows the first 2–3).
let posters = [
    Poster(shot: "s_reminders", out: "poster_1", head: "Never miss an\noil change.",      sub: "Reminders by date or mileage — fired in time."),
    Poster(shot: "s_costs",     out: "poster_2", head: "Know what your\ncar costs.",       sub: "Fuel, charging, service & expenses in one number."),
    Poster(shot: "s_paywall",   out: "poster_3", head: "No account.\nNo subscription.",    sub: "Pay once · $5.99 · your data stays yours."),
    Poster(shot: "s_garage",    out: "poster_4", head: "All your cars,\none garage.",      sub: "Every vehicle's upkeep, in one place."),
    Poster(shot: "s_ev",        out: "poster_5", head: "Built for EVs,\ntoo.",             sub: "kWh, mi/kWh, home vs public, battery health."),
    Poster(shot: "s_add",       out: "poster_6", head: "Log service\nin seconds.",         sub: "Photos, receipts and smart prefill."),
]

func drawText(_ s: String, font: NSFont, color: NSColor, topY: Double, height: Double, tracking: Double = 0) {
    let para = NSMutableParagraphStyle(); para.alignment = .center; para.lineSpacing = 2
    var attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .paragraphStyle: para]
    if tracking != 0 { attrs[.kern] = tracking }
    let rect = NSRect(x: 60, y: H - topY - height, width: W - 120, height: height)
    (s as NSString).draw(in: rect, withAttributes: attrs)
}

for p in posters {
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W), pixelsHigh: Int(H),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { continue }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // background + faint warm glow at top
    paper.setFill(); NSRect(x: 0, y: 0, width: W, height: H).fill()
    if let grad = NSGradient(colors: [orange.withAlphaComponent(0.10), paper.withAlphaComponent(0)]) {
        grad.draw(in: NSRect(x: -300, y: H - 1100, width: W + 600, height: 1100), relativeCenterPosition: NSPoint(x: 0, y: 0.6))
    }

    // text
    drawText("GARAGELY", font: .systemFont(ofSize: 34, weight: .heavy), color: orange, topY: 150, height: 44, tracking: 6)
    drawText(p.head, font: .systemFont(ofSize: 104, weight: .bold), color: ink, topY: 220, height: 300)
    drawText(p.sub, font: .systemFont(ofSize: 40, weight: .medium), color: mid, topY: 540, height: 110)

    // device screenshot with rounded corners + shadow
    if let img = NSImage(contentsOfFile: "\(dir)/shots/\(p.shot).png") {
        let sw = 1000.0, sh = sw / W * H
        let x = (W - sw) / 2, topY = 700.0
        let frame = NSRect(x: x, y: H - topY - sh, width: sw, height: sh)
        let shadow = NSShadow(); shadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
        shadow.shadowBlurRadius = 40; shadow.shadowOffset = NSSize(width: 0, height: -16)
        NSGraphicsContext.saveGraphicsState(); shadow.set()
        let clip = NSBezierPath(roundedRect: frame, xRadius: 56, yRadius: 56)
        clip.fill()  // gives the shadow a solid shape
        NSGraphicsContext.restoreGraphicsState()
        clip.setClip()
        img.draw(in: frame)
    }

    NSGraphicsContext.restoreGraphicsState()
    if let data = rep.representation(using: .png, properties: [:]) {
        try? data.write(to: URL(fileURLWithPath: "\(dir)/posters/\(p.out).png"))
        print("wrote \(p.out)")
    }
}
print("done")
