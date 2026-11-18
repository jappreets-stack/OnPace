import AppKit
let a = CommandLine.arguments   // out big left right
let W: CGFloat = 1206, H: CGFloat = 2622
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W), pixelsHigh: Int(H), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = NSSize(width: W, height: H)
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSGradient(colors: [NSColor(red: 0.04, green: 0, blue: 0, alpha: 1), NSColor(red: 0.16, green: 0.01, blue: 0.01, alpha: 1), .black])!
    .draw(in: NSRect(x: 0, y: 0, width: W, height: H), angle: -90)
let red = NSColor(red: 1, green: 0.23, blue: 0.19, alpha: 1)
func font(_ size: CGFloat, _ weight: NSFont.Weight) -> NSFont {
    let f = NSFont.systemFont(ofSize: size, weight: weight)
    return f.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: size) } ?? f
}
func text(_ s: String, top: CGFloat, size: CGFloat, weight: NSFont.Weight, color: NSColor, line: CGFloat = 0) {
    let p = NSMutableParagraphStyle(); p.alignment = .center; if line > 0 { p.minimumLineHeight = line; p.maximumLineHeight = line }
    let str = NSAttributedString(string: s, attributes: [.font: font(size, weight), .foregroundColor: color, .paragraphStyle: p])
    let box = str.boundingRect(with: NSSize(width: W - 160, height: 2000), options: [.usesLineFragmentOrigin])
    str.draw(with: NSRect(x: 80, y: H - top - box.height, width: W - 160, height: box.height), options: [.usesLineFragmentOrigin])
}
text("Night mode in red", top: 200, size: 104, weight: .heavy, color: red)
text("Your Apple Watch in red on black, easy on your eyes. Turns on by itself after sunset.", top: 360, size: 50, weight: .medium,
     color: NSColor(red: 1, green: 0.45, blue: 0.40, alpha: 1), line: 64)
func watch(_ path: String, x: CGFloat, top: CGFloat, w: CGFloat) {
    guard let img = NSImage(contentsOfFile: path) else { fatalError(path) }
    let h = w * 514 / 422, r = NSRect(x: x, y: H - top - h, width: w, height: h), rad = w * 0.2
    let outer = NSBezierPath(roundedRect: r.insetBy(dx: -14, dy: -14), xRadius: rad + 14, yRadius: rad + 14)
    NSGraphicsContext.saveGraphicsState()
    let sh = NSShadow(); sh.shadowColor = red.withAlphaComponent(0.55); sh.shadowBlurRadius = 70; sh.set()
    NSColor(white: 0.62, alpha: 1).setFill(); outer.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSColor(white: 0.30, alpha: 1).setStroke(); outer.lineWidth = 3; outer.stroke()
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(roundedRect: r, xRadius: rad, yRadius: rad).addClip()
    NSColor.black.setFill(); r.fill()
    NSGraphicsContext.current?.imageInterpolation = .high
    img.draw(in: r)
    NSGraphicsContext.restoreGraphicsState()
}
watch(a[2], x: (W - 640) / 2, top: 700, w: 640)
watch(a[3], x: 60, top: 1560, w: 525)
watch(a[4], x: W - 60 - 525, top: 1560, w: 525)
try! rep.representation(using: .jpeg, properties: [.compressionFactor: 1.0])!.write(to: URL(fileURLWithPath: a[1]))
