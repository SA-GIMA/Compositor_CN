import CoreGraphics

nonisolated enum AdjustmentSurface {
    static func draw(in context: CGContext, body: (CGContext) -> Void) {
        let bounds = context.boundingBoxOfClipPath.integral
        guard bounds.width > 0, bounds.height > 0, bounds.width*bounds.height <= 100_000_000,
              let surface = try? BrushRaster.context(width: Int(bounds.width), height: Int(bounds.height), mask: false) else { return }
        surface.translateBy(x: -bounds.minX, y: -bounds.minY)
        body(surface)
        guard let image = surface.makeImage() else { return }
        context.saveGState()
        context.translateBy(x: bounds.minX, y: bounds.maxY)
        context.scaleBy(x: 1, y: -1)
        context.draw(image, in: CGRect(origin: .zero, size: bounds.size))
        context.restoreGState()
    }
}
