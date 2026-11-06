import AppKit
import Foundation

// Export technical macOS/UI renditions of the approved raster master; no logo redrawing.
let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let folder = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "build/TecWisper.iconset", isDirectory: true)
let masterURL = root.appendingPathComponent("_branding/tecwisper-icon-master.png")
guard let source = NSImage(contentsOf: masterURL), let sourceData = try? Data(contentsOf: masterURL), let sourceBitmap = NSBitmapImageRep(data: sourceData) else { fatalError("Logo-Master fehlt: \(masterURL.path)") }
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
func render(_ pixels: Int, to url: URL) throws {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    bitmap.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    NSGraphicsContext.current?.imageInterpolation = .high
    source.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels), from: .zero, operation: .copy, fraction: 1, respectFlipped: false, hints: [.interpolation: NSImageInterpolation.high])
    NSGraphicsContext.restoreGraphicsState()
    try bitmap.representation(using: .png, properties: [:])!.write(to: url)
}
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        try render(size * scale, to: folder.appendingPathComponent(name))
    }
}
let brand = root.appendingPathComponent("TecWisper/Resources/Brand", isDirectory: true)
try FileManager.default.createDirectory(at: brand, withIntermediateDirectories: true)
try render(256, to: brand.appendingPathComponent("AppLogo.png"))
try render(512, to: brand.appendingPathComponent("AppLogo@2x.png"))
try render(22, to: brand.appendingPathComponent("MenuBarLogo.png"))
try render(44, to: brand.appendingPathComponent("MenuBarLogo@2x.png"))
try render(1024, to: root.appendingPathComponent("_branding/TecWisper-Icon-1024.png"))
print("Logo-Master: \(sourceBitmap.pixelsWide) × \(sourceBitmap.pixelsHigh), Alpha am Rand: \(sourceBitmap.colorAt(x: 0, y: 0)?.alphaComponent ?? -1)")
print("Exportiert: 10 ICNS-Renditionen, UI- und Menüleisten-Logo, 1024-px-PNG.")
