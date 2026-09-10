import AppKit
import CoreGraphics
import PDFKit
import XCTest
@testable import MiniTray

final class TrayPreviewRendererTests: XCTestCase {
    private func pdfData(rotation: Int = 0, cropped: Bool = false) throws -> Data {
        let bytes = NSMutableData()
        let consumer = try XCTUnwrap(CGDataConsumer(data: bytes))
        var page = CGRect(x: 0, y: 0, width: 200, height: 400)
        let context = try XCTUnwrap(CGContext(consumer: consumer, mediaBox: &page, nil))
        context.beginPDFPage(nil)
        // Sin pintar papel: reproduce el PDF transparente notificado por el usuario.
        context.setFillColor(red: 0.05, green: 0.15, blue: 0.25, alpha: 1)
        context.fill(CGRect(x: 50, y: 130, width: 100, height: 100))
        context.endPDFPage()
        context.closePDF()
        let document = try XCTUnwrap(PDFDocument(data: bytes as Data))
        let first = try XCTUnwrap(document.page(at: 0))
        first.rotation = rotation
        if cropped { first.setBounds(CGRect(x: 20, y: 30, width: 160, height: 320), for: .cropBox) }
        return try XCTUnwrap(document.dataRepresentation())
    }

    private func withPDF(rotation: Int = 0, cropped: Bool = false, _ body: (URL, Data) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("MiniTrayPreviewTests-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("documento.pdf")
        let data = try pdfData(rotation: rotation, cropped: cropped)
        try data.write(to: url)
        try body(url, data)
        XCTAssertEqual(try Data(contentsOf: url), data, "La miniatura no puede modificar el PDF original")
    }

    private func bitmap(_ image: NSImage) throws -> NSBitmapImageRep {
        NSBitmapImageRep(cgImage: try XCTUnwrap(image.cgImage(forProposedRect: nil, context: nil, hints: nil)))
    }

    private func assertWhitePaper(_ image: NSImage, file: StaticString = #filePath, line: UInt = #line) throws {
        let pixels = try bitmap(image)
        for (x, y) in [(1, 1), (pixels.pixelsWide - 2, 1), (1, pixels.pixelsHigh - 2),
                       (pixels.pixelsWide - 2, pixels.pixelsHigh - 2)] {
            let color = try XCTUnwrap(pixels.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB))
            XCTAssertEqual(color.alphaComponent, 1, accuracy: 0.001, file: file, line: line)
            XCTAssertEqual(color.redComponent, 1, accuracy: 0.001, file: file, line: line)
            XCTAssertEqual(color.greenComponent, 1, accuracy: 0.001, file: file, line: line)
            XCTAssertEqual(color.blueComponent, 1, accuracy: 0.001, file: file, line: line)
        }
        let ink = try XCTUnwrap(pixels.colorAt(x: pixels.pixelsWide / 2, y: pixels.pixelsHigh / 2))
        XCTAssertLessThan(ink.redComponent, 0.5, "Debe conservar el contenido, no devolver una hoja en blanco", file: file, line: line)
    }

    func testTransparentPDFGetsOpaquePaperWithoutChangingItsContents() throws {
        try withPDF { url, _ in
            let image = try XCTUnwrap(PDFPreviewRenderer.image(for: url, size: CGSize(width: 128, height: 128), scale: 2))
            XCTAssertEqual(image.size.width / image.size.height, 0.5, accuracy: 0.01)
            try assertWhitePaper(image)
        }
    }

    func testRetinaRasterIsSharpAndRespectsThePageRotation() throws {
        try withPDF(rotation: 90) { url, _ in
            let image = try XCTUnwrap(PDFPreviewRenderer.image(for: url, size: CGSize(width: 128, height: 128), scale: 2))
            XCTAssertEqual(image.size.width / image.size.height, 2, accuracy: 0.01)
            let pixels = try bitmap(image)
            XCTAssertEqual(pixels.pixelsWide, 256)
            XCTAssertEqual(pixels.pixelsHigh, 128)
            try assertWhitePaper(image)
        }
    }

    func testCropBoxWithAnOffsetStaysOpaqueAndProportional() throws {
        try withPDF(cropped: true) { url, _ in
            let image = try XCTUnwrap(PDFPreviewRenderer.image(for: url, size: CGSize(width: 128, height: 128), scale: 1))
            XCTAssertEqual(image.size.width / image.size.height, 0.5, accuracy: 0.01)
            try assertWhitePaper(image)
        }
    }

    func testSmallPDFIsUpscaledToRetinaWithoutAddingFalsePageMargins() throws {
        try withPDF { url, _ in
            let image = try XCTUnwrap(PDFPreviewRenderer.image(for: url, size: CGSize(width: 128, height: 128), scale: 4))
            let pixels = try bitmap(image)
            let inkWidth = (0..<pixels.pixelsWide).filter {
                (pixels.colorAt(x: $0, y: pixels.pixelsHigh / 2)?.redComponent ?? 1) < 0.5
            }.count
            XCTAssertEqual(Double(inkWidth), Double(pixels.pixelsWide) / 2, accuracy: 2)
        }
    }

    func testInvalidDimensionsAndMissingPDFUseNoBrokenRaster() throws {
        let missing = URL(fileURLWithPath: "/tmp/MiniTray-absent-\(UUID()).pdf")
        XCTAssertNil(PDFPreviewRenderer.image(for: missing, size: CGSize(width: 128, height: 128), scale: 2))
        try withPDF { url, _ in
            XCTAssertNil(PDFPreviewRenderer.image(for: url, size: .zero, scale: 2))
            XCTAssertNil(PDFPreviewRenderer.image(for: url, size: CGSize(width: 128, height: 128), scale: .infinity))
        }
    }

    @MainActor
    func testLoaderSharesAnOpaquePDFPreviewAcrossCompactExpandedAndDragSizes() throws {
        try withPDF { url, _ in
            let loader = NativeThumbnailLoader()
            let completed = expectation(description: "Se entregan ambas miniaturas sin bloquear")
            completed.expectedFulfillmentCount = 2
            var images: [NSImage] = []
            for size in [CGSize(width: 70, height: 58), CGSize(width: 120, height: 94)] {
                loader.loadThumbnail(for: url, size: size, scale: 2) { image in
                    images.append(image)
                    completed.fulfill()
                }
            }
            wait(for: [completed], timeout: 5)
            XCTAssertEqual(images.count, 2)
            XCTAssertTrue(images[0] === images[1])
            XCTAssertTrue(loader.cachedThumbnail(for: url, scale: 2) === images[0])
            try assertWhitePaper(images[0])
        }
    }

    @MainActor
    func testTransferBadgeIsNotShownWhenCopyingOrExportingAMemoryImage() {
        let file = TrayItem(url: URL(fileURLWithPath: "/tmp/ejemplo.pdf"))
        let image = TrayItem(imageData: Data(), image: NSImage(size: CGSize(width: 20, height: 20)), name: "imagen.png")
        XCTAssertTrue(DragPreviewRenderer.showsTransferBadge(for: file, modifiers: []))
        XCTAssertTrue(DragPreviewRenderer.showsTransferBadge(for: file, modifiers: .command))
        XCTAssertFalse(DragPreviewRenderer.showsTransferBadge(for: file, modifiers: .option))
        XCTAssertFalse(DragPreviewRenderer.showsTransferBadge(for: file, modifiers: [.option, .command]))
        XCTAssertFalse(DragPreviewRenderer.showsTransferBadge(for: image, modifiers: []))
        XCTAssertEqual(TrayDragPolicy.operations(for: [file]), [.copy, .move])
    }

    @MainActor
    func testDragPreviewKeepsWhitePaperAndOnlyChangesTheSmallBadgeRegion() throws {
        try withPDF { url, _ in
            let preview = try XCTUnwrap(PDFPreviewRenderer.image(for: url, size: CGSize(width: 128, height: 128), scale: 2))
            let plain = DragPreviewRenderer.image(preview: preview, showTransferBadge: false, scale: 2)
            let badged = DragPreviewRenderer.image(preview: preview, showTransferBadge: true, scale: 2)
            XCTAssertEqual(plain.size, badged.size)
            XCTAssertEqual(plain.size.width, 68, accuracy: 0.01)
            XCTAssertEqual(plain.size.height, 124, accuracy: 0.01)
            let a = try bitmap(plain)
            let b = try bitmap(badged)
            XCTAssertEqual(a.pixelsHigh, 248)
            var differences = 0
            for y in 0..<a.pixelsHigh {
                for x in 0..<a.pixelsWide {
                    if a.colorAt(x: x, y: y) != b.colorAt(x: x, y: y) {
                        differences += 1
                        XCTAssertGreaterThanOrEqual(x, a.pixelsWide - 34)
                    }
                }
            }
            XCTAssertGreaterThan(differences, 0)
            XCTAssertLessThanOrEqual(differences, 34 * 34)
            XCTAssertEqual(try XCTUnwrap(a.colorAt(x: 1, y: 1)).alphaComponent, 0, accuracy: 0.001)
        }
    }

    @MainActor
    func testTransparentImageIsNotGivenPDFWhitePaper() throws {
        let preview = NSImage(size: CGSize(width: 40, height: 40), flipped: false) { rect in
            NSColor.systemBlue.setFill()
            rect.insetBy(dx: 10, dy: 10).fill()
            return true
        }
        let image = DragPreviewRenderer.image(preview: preview, showTransferBadge: false, scale: 2)
        let pixels = try bitmap(image)
        XCTAssertEqual(try XCTUnwrap(pixels.colorAt(x: 15, y: 15)).alphaComponent, 0, accuracy: 0.001)
    }

    @MainActor
    func testSessionMatchesTheFileURLInsteadOfAssumingCollectionEnumerationOrder() {
        let first = TrayItem(url: URL(fileURLWithPath: "/tmp/primero.pdf"))
        let second = TrayItem(url: URL(fileURLWithPath: "/tmp/segundo.pdf"))
        let pasteboard = NSPasteboardItem()
        pasteboard.setString(second.fileURL!.absoluteString, forType: .fileURL)
        XCTAssertEqual(TrayDragPreviewSession.matchingItem(pasteboard, index: 0, items: [first, second])?.id, second.id)
        pasteboard.setString("file:///tmp/ajeno.pdf", forType: .fileURL)
        XCTAssertNil(TrayDragPreviewSession.matchingItem(pasteboard, index: 0, items: [first, second]))
    }

    @MainActor
    func testPaperAndTransferBadgeDoNotChangeInDarkAppearance() throws {
        try withPDF { url, _ in
            let preview = try XCTUnwrap(PDFPreviewRenderer.image(for: url, size: CGSize(width: 128, height: 128), scale: 2))
            var light: NSImage!
            var dark: NSImage!
            NSAppearance(named: .aqua)!.performAsCurrentDrawingAppearance {
                light = DragPreviewRenderer.image(preview: preview, showTransferBadge: true, scale: 2)
            }
            NSAppearance(named: .darkAqua)!.performAsCurrentDrawingAppearance {
                dark = DragPreviewRenderer.image(preview: preview, showTransferBadge: true, scale: 2)
            }
            XCTAssertEqual(try bitmap(light).representation(using: .png, properties: [:]),
                           try bitmap(dark).representation(using: .png, properties: [:]))
        }
    }

    @MainActor
    func testMalformedPDFFallsBackToAnIconAndKeepsTheSourceUntouched() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("MiniTrayPreviewTests-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("invalido.pdf")
        let data = Data("Esto no es un PDF válido".utf8)
        try data.write(to: url)
        let loader = NativeThumbnailLoader()
        let completed = expectation(description: "El PDF inválido entrega un icono sin bloquear la UI")
        loader.loadThumbnail(for: url, size: CGSize(width: 120, height: 94), scale: 2) { image in
            XCTAssertGreaterThan(image.size.width, 0)
            XCTAssertGreaterThan(image.size.height, 0)
            completed.fulfill()
        }
        wait(for: [completed], timeout: 5)
        XCTAssertEqual(try Data(contentsOf: url), data)
    }

}
