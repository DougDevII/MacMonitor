// Copyright © 2026 Douglas Almeida dos Santos. Todos os direitos reservados.
import AppKit
import Foundation

let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Resources"
let directory = URL(fileURLWithPath: output, isDirectory: true)
let iconset = directory.appendingPathComponent("AppIcon.iconset", isDirectory: true)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

for (filename, pixels) in [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024)
] {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                  isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.cgContext.scaleBy(x: Double(pixels) / 1024, y: Double(pixels) / 1024)
    let background = NSBezierPath(roundedRect: NSRect(x: 62, y: 62, width: 900, height: 900), xRadius: 205, yRadius: 205)
    NSGradient(starting: NSColor(calibratedRed: 0.16, green: 0.28, blue: 0.46, alpha: 1),
               ending: NSColor(calibratedRed: 0.055, green: 0.085, blue: 0.16, alpha: 1))!
        .draw(in: background, angle: -90)
    let rim = NSBezierPath(roundedRect: NSRect(x: 66, y: 66, width: 892, height: 892), xRadius: 200, yRadius: 200)
    NSColor.white.withAlphaComponent(0.15).setStroke()
    rim.lineWidth = 4
    rim.stroke()
    let ring = NSBezierPath()
    ring.appendArc(withCenter: NSPoint(x: 512, y: 512), radius: 260, startAngle: 215, endAngle: -35, clockwise: true)
    ring.lineWidth = 46
    ring.lineCapStyle = .round
    NSColor.white.withAlphaComponent(0.16).setStroke()
    ring.stroke()
    let active = NSBezierPath()
    active.appendArc(withCenter: NSPoint(x: 512, y: 512), radius: 260, startAngle: 215, endAngle: 55, clockwise: true)
    active.lineWidth = 46
    active.lineCapStyle = .round
    NSColor(calibratedRed: 0.32, green: 0.75, blue: 1, alpha: 1).setStroke()
    active.stroke()
    let needle = NSBezierPath()
    needle.move(to: NSPoint(x: 512, y: 512))
    needle.line(to: NSPoint(x: 640, y: 696))
    needle.lineWidth = 34
    needle.lineCapStyle = .round
    NSColor.white.setStroke()
    needle.stroke()
    NSColor.white.setFill()
    NSBezierPath(ovalIn: NSRect(x: 477, y: 477, width: 70, height: 70)).fill()
    for (x, height) in [(425.0, 52.0), (497.0, 82.0), (569.0, 112.0)] {
        NSColor.white.withAlphaComponent(0.75).setFill()
        NSBezierPath(roundedRect: NSRect(x: x, y: 300, width: 30, height: height), xRadius: 12, yRadius: 12).fill()
    }
    NSGraphicsContext.restoreGraphicsState()
    try bitmap.representation(using: .png, properties: [:])!.write(to: iconset.appendingPathComponent(filename))
}
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconset.path, "-o", directory.appendingPathComponent("AppIcon.icns").path]
try process.run()
process.waitUntilExit()
guard process.terminationStatus == 0 else { fatalError("Falha ao gerar o ícone") }
try FileManager.default.removeItem(at: iconset)
