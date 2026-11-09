import AppKit

/// Renders source artwork inside a transparent 1024px Mac icon canvas at destination; returns nothing or throws.
func renderIcon(source: URL, destination: URL) throws {
    guard let artwork = NSImage(contentsOf: source),
          let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
          ),
          let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw NSError(domain: "LivingMeaning.Icon", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Cannot read the selected artwork or create the icon canvas."
        ])
    }
    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    context.cgContext.clear(CGRect(x: 0, y: 0, width: 1024, height: 1024))
    let bounds = NSRect(x: 56, y: 56, width: 912, height: 912)
    NSBezierPath(roundedRect: bounds, xRadius: 210, yRadius: 210).addClip()
    artwork.draw(in: bounds, from: .zero, operation: .sourceOver, fraction: 1)
    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "LivingMeaning.Icon", code: 2, userInfo: [
            NSLocalizedDescriptionKey: "Cannot encode the application icon."
        ])
    }
    try png.write(to: destination, options: .atomic)
}

guard CommandLine.arguments.count == 3 else {
    fputs("Usage: generate-icon source.png output.png\n", stderr)
    exit(2)
}
try renderIcon(
    source: URL(fileURLWithPath: CommandLine.arguments[1]),
    destination: URL(fileURLWithPath: CommandLine.arguments[2])
)
