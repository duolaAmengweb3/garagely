import Foundation
import CoreImage
import AppKit

// Recolor the master icon into cohesive variants. Hue rotation shifts the
// saturated orange roof to a new hue while the near-neutral graphite/chalk stay put.

let master = CommandLine.arguments[1]
let outDir = CommandLine.arguments[2]

guard let img = CIImage(contentsOf: URL(fileURLWithPath: master)) else { fatalError("no master") }
let ctx = CIContext()

struct Variant { let name: String; let hue: CGFloat; let sat: CGFloat }
// Master roof hue ≈ 25°. Angles below rotate it to each target hue (radians).
let variants: [Variant] = [
    Variant(name: "IconCobalt",  hue: 3.44, sat: 1.0),  // -> ~222° blue
    Variant(name: "IconGreen",   hue: 2.0,  sat: 1.0),  // -> ~140° green
    Variant(name: "IconViolet",  hue: 4.36, sat: 1.0),  // -> ~275° violet
    Variant(name: "IconCrimson", hue: -0.58, sat: 1.05),// -> ~352° crimson
    Variant(name: "IconSlate",   hue: 0.0,  sat: 0.0),  // desaturated graphite
]

func render(_ ci: CIImage, to url: URL, size: CGFloat) {
    let scaleX = size / ci.extent.width
    let scaled = ci.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleX))
    guard let cg = ctx.createCGImage(scaled, from: CGRect(x: 0, y: 0, width: size, height: size)) else { return }
    let rep = NSBitmapImageRep(cgImage: cg)
    rep.size = NSSize(width: size, height: size)
    guard let data = rep.representation(using: .png, properties: [:]) else { return }
    try? data.write(to: url)
}

for v in variants {
    var out = img
    if v.hue != 0 {
        let f = CIFilter(name: "CIHueAdjust")!
        f.setValue(out, forKey: kCIInputImageKey)
        f.setValue(v.hue, forKey: kCIInputAngleKey)
        out = f.outputImage!
    }
    if v.sat != 1.0 {
        let c = CIFilter(name: "CIColorControls")!
        c.setValue(out, forKey: kCIInputImageKey)
        c.setValue(v.sat, forKey: kCIInputSaturationKey)
        out = c.outputImage!
    }
    render(out, to: URL(fileURLWithPath: "\(outDir)/\(v.name)-1024.png"), size: 1024)
    render(out, to: URL(fileURLWithPath: "\(outDir)/\(v.name)-preview.png"), size: 180)
    print("generated \(v.name)")
}
print("done")
