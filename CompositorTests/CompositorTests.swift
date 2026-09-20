import Testing
import CoreGraphics
@testable import Compositor

@MainActor
struct CompositorTests {
    let document = CGSize(width: 1920, height: 1080)

    @Test func dimensionValidation() {
        #expect(CanvasDocument.validDimension("0") == nil)
        #expect(CanvasDocument.validDimension("-1") == nil)
        #expect(CanvasDocument.validDimension("1.5") == nil)
        #expect(CanvasDocument.validDimension("30001") == nil)
        #expect(CanvasDocument.validDimension("9999999999999999999999") == nil)
        #expect(CanvasDocument.validDimension(" 1920 ") == 1920)
        #expect(CanvasDocument.validDimension("30000") == 30000)
    }

    @Test(arguments: [CGFloat(1), CGFloat(2)])
    func actualPixelsAndRoundTrip(backing: CGFloat) {
        var viewport = CanvasViewport()
        viewport.resize(to: CGSize(width: 800, height: 600), backingScale: backing, documentSize: nil)
        for zoom in [CGFloat(0.25), 1, 3.75] {
            viewport.setZoom(zoom, anchoredAt: viewport.center, documentSize: document)
            viewport.translate(by: CGSize(width: 73.5, height: -44.25))
            let pixel = CGPoint(x: 183.25, y: 837.5)
            let viewPoint = viewport.viewPoint(from: pixel, documentSize: document)
            let result = viewport.documentPoint(from: viewPoint, documentSize: document)
            #expect(abs(result.x - pixel.x) < 0.000001)
            #expect(abs(result.y - pixel.y) < 0.000001)
            #expect(abs(viewport.documentRect(document).width * backing - document.width * zoom) < 0.000001)
        }
    }

    @Test func zoomKeepsCursorPixelFixed() {
        var viewport = CanvasViewport()
        viewport.resize(to: CGSize(width: 1000, height: 700), backingScale: 2, documentSize: document)
        let anchor = CGPoint(x: 157, y: 221)
        let before = viewport.documentPoint(from: anchor, documentSize: document)
        viewport.setZoom(4, anchoredAt: anchor, documentSize: document)
        let after = viewport.documentPoint(from: anchor, documentSize: document)
        #expect(abs(before.x - after.x) < 0.000001)
        #expect(abs(before.y - after.y) < 0.000001)
    }

    @Test func fitAndResizeModes() {
        var viewport = CanvasViewport()
        viewport.resize(to: CGSize(width: 800, height: 600), backingScale: 2, documentSize: document)
        let rect = viewport.documentRect(document)
        #expect(rect.width <= 704.000001)
        #expect(rect.height <= 504.000001)
        #expect(rect.midX == 400)
        #expect(rect.midY == 300)
        viewport.translate(by: CGSize(width: 60, height: -35))
        let before = viewport.documentPoint(from: viewport.center, documentSize: document)
        let zoom = viewport.zoom
        viewport.resize(to: CGSize(width: 1200, height: 800), backingScale: 1, documentSize: document)
        let after = viewport.documentPoint(from: viewport.center, documentSize: document)
        #expect(viewport.zoom == zoom)
        #expect(abs(before.x - after.x) < 0.000001)
        #expect(abs(before.y - after.y) < 0.000001)
        viewport.fit(documentSize: document)
        #expect(viewport.pan == .zero)
        #expect(viewport.followsFit)
    }

    @Test func limitsAndNewDocumentReset() {
        let session = EditorSession()
        session.viewport.resize(to: CGSize(width: 800, height: 600), backingScale: 2, documentSize: nil)
        session.createDocument(width: 1920, height: 1080)
        session.zoom(to: 1000)
        #expect(session.viewport.zoom == CanvasViewport.zoomRange.upperBound)
        session.zoom(to: 0)
        #expect(session.viewport.zoom == CanvasViewport.zoomRange.lowerBound)
        session.viewport.translate(by: CGSize(width: 999, height: 888))
        session.createDocument(width: 400, height: 300)
        #expect(session.viewport.followsFit)
        #expect(session.viewport.pan == .zero)
        #expect(session.document?.width == 400)
        session.createDocument(width: 0, height: 200)
        #expect(session.document?.width == 400)
    }
}
