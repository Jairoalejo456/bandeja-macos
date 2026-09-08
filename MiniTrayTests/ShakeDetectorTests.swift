import CoreGraphics
import XCTest
@testable import MiniTray

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

    func testDeliberateVerticalShakeTriggers() {
        var detector = ShakeDetector(configuration: .balanced)
        detector.beginDrag(at: .zero, timestamp: 0)

        let points = [
            CGPoint(x: 1, y: 38),
            CGPoint(x: 0, y: -3),
            CGPoint(x: 2, y: 39),
            CGPoint(x: 1, y: -4)
        ]
        for (index, point) in points.enumerated() {
            let triggered = detector.updateDrag(at: point, timestamp: Double(index + 1) * 0.06)
            XCTAssertEqual(triggered, index == points.indices.last)
        }
    }

    func testDeliberateDiagonalShakeTriggers() {
        var detector = ShakeDetector(configuration: .balanced)
        detector.beginDrag(at: .zero, timestamp: 0)

        let points = [
            CGPoint(x: 31, y: 31),
            CGPoint(x: -3, y: -3),
            CGPoint(x: 32, y: 32),
            CGPoint(x: -4, y: -4)
        ]
        for (index, point) in points.enumerated() {
            let triggered = detector.updateDrag(at: point, timestamp: Double(index + 1) * 0.06)
            XCTAssertEqual(triggered, index == points.indices.last)
        }
    }

    func testCurvedOneWayMotionDoesNotTrigger() {
        var detector = ShakeDetector(configuration: .balanced)
        detector.beginDrag(at: .zero, timestamp: 0)

        let points = [
            CGPoint(x: 24, y: 8),
            CGPoint(x: 42, y: 28),
            CGPoint(x: 48, y: 54),
            CGPoint(x: 36, y: 78),
            CGPoint(x: 14, y: 91)
        ]
        for (index, point) in points.enumerated() {
            XCTAssertFalse(detector.updateDrag(at: point, timestamp: Double(index + 1) * 0.06))
        }
    }

    func testExternalDragGateRejectsStaleFilePasteboardDuringOrdinarySelection() {
        var gate = ExternalDragRecognitionGate(initialChangeCount: 12)
        gate.beginPress()

        XCTAssertFalse(
            gate.recognizesActiveImportableDrag(
                observedChangeCount: 12,
                hasImportableContent: true
            ),
            "El contenido antiguo del portapapeles de arrastre no debe convertir una selección en un drag de archivo"
        )
    }

    func testExternalDragGateRejectsChangedPasteboardWithoutImportableContent() {
        var gate = ExternalDragRecognitionGate(initialChangeCount: 12)
        gate.beginPress()

        XCTAssertFalse(
            gate.recognizesActiveImportableDrag(
                observedChangeCount: 13,
                hasImportableContent: false
            )
        )
    }

    func testExternalDragGateAcceptsFreshImportableDrag() {
        var gate = ExternalDragRecognitionGate(initialChangeCount: 12)
        gate.beginPress()

        XCTAssertTrue(
            gate.recognizesActiveImportableDrag(
                observedChangeCount: 13,
                hasImportableContent: true
            )
        )

        gate.endPress(observedChangeCount: 13)
        gate.beginPress()
        XCTAssertFalse(
            gate.recognizesActiveImportableDrag(
                observedChangeCount: 13,
                hasImportableContent: true
            )
        )
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

    func testGlobalSampleProcessorOnlyEndsAfterAShakeAndOnlyOnce() {
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
            .none,
            "Un clic normal no debe tratarse como el final de un arrastre con sacudida"
        )

        XCTAssertEqual(
            processor.process(isLeftButtonPressed: true, point: .zero, timestamp: 0.3),
            .none
        )
        XCTAssertEqual(
            processor.process(isLeftButtonPressed: true, point: CGPoint(x: 38, y: 0), timestamp: 0.34),
            .none
        )
        XCTAssertEqual(
            processor.process(isLeftButtonPressed: true, point: CGPoint(x: -3, y: 0), timestamp: 0.41),
            .none
        )
        XCTAssertEqual(
            processor.process(isLeftButtonPressed: true, point: CGPoint(x: 39, y: 0), timestamp: 0.48),
            .none
        )
        XCTAssertEqual(
            processor.process(isLeftButtonPressed: true, point: CGPoint(x: -4, y: 0), timestamp: 0.55),
            .shake(CGPoint(x: -4, y: 0))
        )
        XCTAssertEqual(
            processor.process(isLeftButtonPressed: false, point: .zero, timestamp: 0.6),
            .dragEnded
        )
        XCTAssertEqual(
            processor.process(isLeftButtonPressed: false, point: .zero, timestamp: 0.7),
            .none
        )
    }

    func testGlobalSampleProcessorIgnoresAnEntirePressThatStartsInsideTheTray() {
        var processor = GlobalDragSampleProcessor(configuration: .balanced)

        XCTAssertEqual(
            processor.process(
                isLeftButtonPressed: true,
                point: .zero,
                timestamp: 0,
                ignoreNewPress: true
            ),
            .none
        )

        let shakePoints = [
            CGPoint(x: 40, y: 0),
            CGPoint(x: -4, y: 0),
            CGPoint(x: 42, y: 0),
            CGPoint(x: -6, y: 0)
        ]
        for (index, point) in shakePoints.enumerated() {
            XCTAssertEqual(
                processor.process(
                    isLeftButtonPressed: true,
                    point: point,
                    timestamp: Double(index + 1) * 0.05
                ),
                .none
            )
        }

        XCTAssertTrue(processor.isIgnoringCurrentPress)
        XCTAssertEqual(
            processor.process(isLeftButtonPressed: false, point: .zero, timestamp: 0.3),
            .none,
            "Soltar un clic interno no debe cerrar una bandeja vacía ni finalizar un drag externo"
        )
        XCTAssertFalse(processor.isIgnoringCurrentPress)
    }
}
