// Renders the 1024px MechPad app icon: a keycap emitting haptic ripples.
// Usage: swift Icon/make_icon.swift <out.png>
import AppKit

let size = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext
// Flip to top-left origin so coordinates read like a design spec.
ctx.translateBy(x: 0, y: CGFloat(size)); ctx.scaleBy(x: 1, y: -1)

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}
func fill(_ path: CGPath, top: UInt32, bottom: UInt32, from y0: CGFloat, to y1: CGFloat) {
    ctx.saveGState(); ctx.addPath(path); ctx.clip()
    let g = CGGradient(colorsSpace: nil, colors: [rgb(top), rgb(bottom)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: y0), end: CGPoint(x: 0, y: y1), options: [])
    ctx.restoreGState()
}
func rr(_ r: CGRect, _ radius: CGFloat) -> CGPath { CGPath(roundedRect: r, cornerWidth: radius, cornerHeight: radius, transform: nil) }

// Background squircle (Apple grid: 824px body, 100px margin) with drop shadow.
let bg = CGRect(x: 100, y: 100, width: 824, height: 824)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: 12), blur: 28, color: rgb(0x000000, 0.35))
ctx.addPath(rr(bg, 185)); ctx.setFillColor(rgb(0x1E2030)); ctx.fillPath()
ctx.restoreGState()
fill(rr(bg, 185), top: 0x3A3F5C, bottom: 0x161827, from: 100, to: 924)

// Haptic ripples on both sides of the keycap.
let accent: UInt32 = 0xF4A261
let center = CGPoint(x: 512, y: 512)
for (i, radius) in [250.0, 305.0, 360.0].enumerated() {
    ctx.setStrokeColor(rgb(accent, [1.0, 0.62, 0.3][i]))
    ctx.setLineWidth(30); ctx.setLineCap(.round)
    for mid in [0.0, Double.pi] {
        ctx.addArc(center: center, radius: radius, startAngle: mid - 0.52, endAngle: mid + 0.52, clockwise: false)
        ctx.strokePath()
    }
}

// Keycap: skirt with shadow, then a lighter dished top face.
let skirt = CGRect(x: 322, y: 322, width: 380, height: 390)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: 22), blur: 30, color: rgb(0x000000, 0.55))
ctx.addPath(rr(skirt, 78)); ctx.setFillColor(rgb(0xC9C2B6)); ctx.fillPath()
ctx.restoreGState()
fill(rr(skirt, 78), top: 0xE6DFD3, bottom: 0xA59D90, from: 322, to: 712)
let face = CGRect(x: 362, y: 342, width: 300, height: 300)
fill(rr(face, 58), top: 0xFFFDF8, bottom: 0xEAE3D7, from: 342, to: 642)


NSGraphicsContext.current = nil
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
