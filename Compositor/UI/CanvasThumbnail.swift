import AppKit

/// Layers-panel thumbnails framed by the whole canvas, as Photoshop shows them: a layer's pixels (or its
/// mask) drawn where they sit on a canvas-shaped picture, whatever the layer's own bounds.
enum CanvasThumbnail {
    /// Pixels per point in the pictures, so they stay sharp on Retina displays.
    static let backingScale: CGFloat = 2

    /// The canvas's aspect ratio fitted inside a square slot `box` points wide, in whole points.
    static func fittedSize(canvas: CGSize, box: CGFloat) -> CGSize {
        guard canvas.width > 0, canvas.height > 0, canvas.width.isFinite, canvas.height.isFinite else {
            return CGSize(width: box, height: box)
        }
        let scale = box / max(canvas.width, canvas.height)
        return CGSize(width: max(1, (canvas.width * scale).rounded()), height: max(1, (canvas.height * scale).rounded()))
    }

    /// The transparency checkerboard with the layer's pixels (`image`, usually its small preview) placed
    /// on the canvas by `transform`. Without an image it is an empty canvas.
    static func layer(_ image: CGImage?, transform: LayerTransform, canvas: CGSize, box: CGFloat) -> NSImage {
        render(canvas: canvas, box: box) { context, size, scale in
            context.setFillColor(gray: 0.22, alpha: 1)
            context.fill(CGRect(origin: .zero, size: size))
            context.setFillColor(gray: 0.32, alpha: 1)
            let tile = 6 * backingScale
            for row in 0..<Int(ceil(size.height / tile)) {
                for column in 0..<Int(ceil(size.width / tile)) where (row + column).isMultiple(of: 2) {
                    context.fill(CGRect(x: CGFloat(column) * tile, y: CGFloat(row) * tile, width: tile, height: tile))
                }
            }
            if let image { place(image, transform: transform, scale: scale, in: context) }
        }
    }

    /// The mask placed by `transform`. Outside its layer a mask has no effect, so its edge tone carries on
    /// to the canvas edges: a reveal-all mask reads all white, a hide-all mask all black.
    static func mask(_ image: CGImage, transform: LayerTransform, canvas: CGSize, box: CGFloat) -> NSImage {
        render(canvas: canvas, box: box) { context, size, scale in
            context.setFillColor(gray: edgeTone(of: image), alpha: 1)
            context.fill(CGRect(origin: .zero, size: size))
            place(image, transform: transform, scale: scale, in: context)
        }
    }

    /// The mean gray (0–1) of an image's outermost pixels.
    static func edgeTone(of image: CGImage) -> CGFloat {
        let width = image.width, height = image.height
        guard width > 0, height > 0,
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
                                      space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue),
              let data = context.data?.assumingMemoryBound(to: UInt8.self) else { return 1 }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        var total = 0, count = 0
        for y in 0..<height {
            let edgeRow = y == 0 || y == height - 1
            for x in 0..<width where edgeRow || x == 0 || x == width - 1 {
                total += Int(data[y * width + x])
                count += 1
            }
        }
        return count == 0 ? 1 : CGFloat(total) / CGFloat(count) / 255
    }

    /// A canvas-shaped picture: `draw` gets a top-left context, its size in pixels, and pixels per document pixel.
    private static func render(canvas: CGSize, box: CGFloat, draw: (CGContext, CGSize, CGFloat) -> Void) -> NSImage {
        let points = fittedSize(canvas: canvas, box: box)
        let width = Int(points.width * backingScale), height = Int(points.height * backingScale)
        guard let context = try? BrushRaster.context(width: width, height: height, mask: false) else { return NSImage(size: points) }
        draw(context, CGSize(width: width, height: height), canvas.width > 0 ? CGFloat(width) / canvas.width : 1)
        guard let image = context.makeImage() else { return NSImage(size: points) }
        return NSImage(cgImage: image, size: points)
    }

    /// Draws `image` where `transform` puts it on the canvas, the way the canvas itself places layers.
    private static func place(_ image: CGImage, transform: LayerTransform, scale: CGFloat, in context: CGContext) {
        LayerRenderer.draw(image, transform: transform, center: CGPoint(x: transform.center.x * scale, y: transform.center.y * scale),
                           scale: scale, in: context)
    }
}
