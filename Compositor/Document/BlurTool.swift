import AppKit
import CoreImage

extension EditorSession {
    /// What a Blur stroke paints: the active layer (or, with `mask`, its mask) as the canvas shows it, at document
    /// size, softened by an amount that follows the brush size. It is taken when the stroke starts, so going over an
    /// area again in a new stroke softens it further, as in Photoshop.
    func blurSample(_ document: CanvasDocument, mask: Bool = false) -> CGImage? {
        guard let layer = activeLayer else { return nil }
        let sigma = min(30, max(1.5, Double(brushSettings.diameter) / 10))
        let extent = CGRect(x: 0, y: 0, width: document.width, height: document.height)
        if mask {
            guard let owned = layer.mask,
                  let context = try? BrushRaster.context(width: document.width, height: document.height, mask: true) else { return nil }
            // Past its pixels a mask keeps its edge tone, so blurring near its edge doesn't pull in the wrong one.
            context.setFillColor(gray: LayerMask.background(of: owned.asset.thumbnail), alpha: 1)
            context.fill(extent)
            // Coverage only adds white, so the mask's own area starts black.
            let placement = layer.maskTransform
            context.saveGState()
            context.translateBy(x: placement.center.x, y: placement.center.y)
            context.rotate(by: placement.radians)
            context.scaleBy(x: placement.flipX ? -1 : 1, y: placement.flipY ? 1 : -1)
            context.setFillColor(gray: 0, alpha: 1)
            context.fill(CGRect(x: -placement.size.width / 2, y: -placement.size.height / 2,
                                width: placement.size.width, height: placement.size.height))
            context.restoreGState()
            LayerRenderer.drawCoverage(owned.asset.image, transform: placement, in: context)
            guard let sharp = context.makeImage() else { return nil }
            let soft = CIImage(cgImage: sharp).clampedToExtent().applyingGaussianBlur(sigma: sigma).cropped(to: extent)
            return try? PixelAdjust.render(soft, width: sharp.width, height: sharp.height, isMask: true)
        }
        guard let image = layer.asset?.image,
              let context = try? BrushRaster.context(width: document.width, height: document.height, mask: false) else { return nil }
        let transform = displayedTransform(for: layer)
        LayerRenderer.draw(image, transform: transform, center: transform.center, in: context)
        guard let sharp = context.makeImage() else { return nil }
        let soft = CIImage(cgImage: sharp).applyingGaussianBlur(sigma: sigma).cropped(to: extent)
        return try? PixelAdjust.render(soft, width: sharp.width, height: sharp.height, isMask: false)
    }
}
