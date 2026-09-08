import AppKit
import XCTest
@testable import MiniTray

final class TrayInteractionGeometryTests: XCTestCase {
    func testAspectFitKeepsWholePortraitImageVisible() {
        let rect = AspectFitLayout.rect(
            for: CGSize(width: 768, height: 1_376),
            in: CGRect(x: 0, y: 0, width: 136, height: 108)
        )

        XCTAssertEqual(rect.height, 108, accuracy: 0.001)
        XCTAssertEqual(rect.width, 60.279, accuracy: 0.001)
        XCTAssertEqual(rect.midX, 68, accuracy: 0.001)
        XCTAssertEqual(rect.midY, 54, accuracy: 0.001)
    }

    func testAspectFitKeepsWholeLandscapeImageVisible() {
        let rect = AspectFitLayout.rect(
            for: CGSize(width: 1_600, height: 900),
            in: CGRect(x: 0, y: 0, width: 136, height: 108)
        )

        XCTAssertEqual(rect.width, 136, accuracy: 0.001)
        XCTAssertEqual(rect.height, 76.5, accuracy: 0.001)
        XCTAssertEqual(rect.midX, 68, accuracy: 0.001)
        XCTAssertEqual(rect.midY, 54, accuracy: 0.001)
    }

    @MainActor
    func testCompactPreviewRegistersAsFileAndImageDropDestination() {
        let view = CompactDragSourceNSView(frame: CGRect(x: 0, y: 0, width: 174, height: 130))

        XCTAssertTrue(view.registeredDraggedTypes.contains(.fileURL))
        XCTAssertTrue(view.registeredDraggedTypes.contains(.png))
        XCTAssertTrue(view.registeredDraggedTypes.contains(.tiff))
    }

    @MainActor
    func testExpandedCollectionAcceptsTheFirstMouseForImmediateDragging() {
        let collection = DoubleClickCollectionView(frame: CGRect(x: 0, y: 0, width: 480, height: 232))
        let background = FirstMouseView()
        let image = FirstMouseImageView()
        let label = FirstMouseTextField(labelWithString: "Archivo")

        XCTAssertTrue(collection.acceptsFirstMouse(for: nil))
        XCTAssertTrue(background.acceptsFirstMouse(for: nil))
        XCTAssertTrue(image.acceptsFirstMouse(for: nil))
        XCTAssertTrue(label.acceptsFirstMouse(for: nil))
    }
}
