import CoreGraphics
import XCTest
@testable import Bandeja

final class ShakeDetectorTests: XCTestCase {
    func testDeliberateHorizontalShakeTriggers() {
        var detector = ShakeDetector(configuration: .balanced)
        detector.beginDrag(at: CGPoint(x: 0, y: 0), timestamp: 0)

        XCTAssertFalse(detector.updateDrag(at: CGPoint(x: 38, y: 1), timestamp: 0.04))
        XCTAssertFalse(detector.updateDrag(at: CGPoint(x: -3, y: 0), timestamp: 0.11))
        XCTAssertFalse(detector.updateDrag(at: CGPoint(x: 39, y: 2), timestamp: 0.18))
        XCTAssertTrue(detector.updateDrag(at: CGPoint(x: -4, y: 1), timestamp: 0.25))
    }

    func testNormalDragDoesNotTrigger() {
        var detector = ShakeDetector(configuration: .balanced)
        detector.beginDrag(at: .zero, timestamp: 0)

        for index in 1...20 {
            let time = Double(index) * 0.03
            let point = CGPoint(x: CGFloat(index * 9), y: CGFloat(index * 2))
            XCTAssertFalse(detector.updateDrag(at: point, timestamp: time))
        }
    }

    func testSmallJitterDoesNotTrigger() {
        var detector = ShakeDetector(configuration: .balanced)
        detector.beginDrag(at: .zero, timestamp: 0)

        let points: [CGFloat] = [10, -8, 12, -9, 11, -7, 9, -6]
        for (index, x) in points.enumerated() {
            XCTAssertFalse(
                detector.updateDrag(
                    at: CGPoint(x: x, y: 0),
                    timestamp: Double(index + 1) * 0.05
                )
            )
        }
    }

    func testSlowDirectionChangesDoNotTrigger() {
        var detector = ShakeDetector(configuration: .balanced)
        detector.beginDrag(at: .zero, timestamp: 0)

        let points: [CGFloat] = [40, -5, 42, -6, 43]
        for (index, x) in points.enumerated() {
            XCTAssertFalse(
                detector.updateDrag(
                    at: CGPoint(x: x, y: 0),
                    timestamp: 0.04 + Double(index) * 0.34
                )
            )
        }
    }

    func testVerticalDominantMotionDoesNotTrigger() {
        var detector = ShakeDetector(configuration: .balanced)
        detector.beginDrag(at: .zero, timestamp: 0)

        let points = [
            CGPoint(x: 40, y: 40),
            CGPoint(x: -4, y: 82),
            CGPoint(x: 42, y: 128),
            CGPoint(x: -6, y: 174)
        ]
        for (index, point) in points.enumerated() {
            XCTAssertFalse(detector.updateDrag(at: point, timestamp: Double(index + 1) * 0.06))
        }
    }

    func testDetectorOnlyWorksDuringDragAndResetsOnMouseUp() {
        var detector = ShakeDetector(configuration: .balanced)
        XCTAssertFalse(detector.updateDrag(at: CGPoint(x: 50, y: 0), timestamp: 0.1))

        detector.beginDrag(at: .zero, timestamp: 0.2)
        XCTAssertFalse(detector.updateDrag(at: CGPoint(x: 40, y: 0), timestamp: 0.24))
        detector.endDrag()
        XCTAssertFalse(detector.updateDrag(at: CGPoint(x: -10, y: 0), timestamp: 0.3))
        XCTAssertFalse(detector.isDragging)
    }

    func testGlobalSampleProcessorDetectsShakeWhileButtonRemainsPressed() {
        var processor = GlobalDragSampleProcessor(configuration: .balanced)

        XCTAssertEqual(
            processor.process(isLeftButtonPressed: true, point: .zero, timestamp: 0),
            .none
        )
        XCTAssertEqual(
            processor.process(isLeftButtonPressed: true, point: CGPoint(x: 38, y: 1), timestamp: 0.04),
            .none
        )
        XCTAssertEqual(
            processor.process(isLeftButtonPressed: true, point: CGPoint(x: -3, y: 0), timestamp: 0.11),
            .none
        )
        XCTAssertEqual(
            processor.process(isLeftButtonPressed: true, point: CGPoint(x: 39, y: 2), timestamp: 0.18),
            .none
        )
        XCTAssertEqual(
            processor.process(isLeftButtonPressed: true, point: CGPoint(x: -4, y: 1), timestamp: 0.25),
            .shake(CGPoint(x: -4, y: 1))
        )
    }

    func testGlobalSampleProcessorEndsOnlyOnceWhenButtonIsReleased() {
        var processor = GlobalDragSampleProcessor(configuration: .balanced)

        XCTAssertEqual(
            processor.process(isLeftButtonPressed: false, point: .zero, timestamp: 0),
            .none
        )
        XCTAssertEqual(
            processor.process(isLeftButtonPressed: true, point: .zero, timestamp: 0.1),
            .none
        )
        XCTAssertEqual(
            processor.process(isLeftButtonPressed: false, point: .zero, timestamp: 0.2),
            .dragEnded
        )
        XCTAssertEqual(
            processor.process(isLeftButtonPressed: false, point: .zero, timestamp: 0.3),
            .none
        )
    }
}
