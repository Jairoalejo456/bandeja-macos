import AppKit
import SwiftUI
import XCTest
@testable import MiniTray

final class PanelPositionerTests: XCTestCase {
    func testPlacementStaysInsideEveryEdge() {
        let visible = CGRect(x: 10, y: 30, width: 1420, height: 850)
        let size = CGSize(width: 392, height: 390)
        let cursors = [
            CGPoint(x: visible.minX, y: visible.minY),
            CGPoint(x: visible.maxX, y: visible.minY),
            CGPoint(x: visible.minX, y: visible.maxY),
            CGPoint(x: visible.maxX, y: visible.maxY),
            CGPoint(x: visible.midX, y: visible.midY)
        ]

        for cursor in cursors {
            let origin = PanelPositioner.origin(near: cursor, panelSize: size, visibleFrame: visible)
            let frame = CGRect(origin: origin, size: size)
            XCTAssertGreaterThanOrEqual(frame.minX, visible.minX)
            XCTAssertLessThanOrEqual(frame.maxX, visible.maxX)
            XCTAssertGreaterThanOrEqual(frame.minY, visible.minY)
            XCTAssertLessThanOrEqual(frame.maxY, visible.maxY)
        }
    }

    func testCompactLayoutDoesNotGrowWithThirtyTwoItems() {
        let oneItem = TrayPanelLayout.size(itemCount: 1, isExpanded: false)
        let thirtyTwoItems = TrayPanelLayout.size(itemCount: 32, isExpanded: false)

        XCTAssertEqual(oneItem, thirtyTwoItems)
        XCTAssertEqual(thirtyTwoItems, CGSize(width: 236, height: 236))

        let expanded = TrayPanelLayout.size(itemCount: 32, isExpanded: true)
        XCTAssertEqual(expanded.width, 480)
        XCTAssertEqual(expanded.height, 540, "La cuadrícula debe usar desplazamiento en lugar de salir de pantalla")
    }

    func testReducedMotionKeepsFeedbackBrief() {
        let regular = TrayMotionProfile(reduceMotion: false)
        let reduced = TrayMotionProfile(reduceMotion: true)

        XCTAssertLessThan(reduced.appearanceDuration, regular.appearanceDuration)
        XCTAssertLessThan(reduced.attentionDuration, regular.attentionDuration)
        XCTAssertLessThan(reduced.dropDuration, regular.dropDuration)
        XCTAssertLessThan(reduced.presentationDuration, regular.presentationDuration)
        XCTAssertLessThan(reduced.cancelDuration, regular.cancelDuration)
        XCTAssertLessThan(reduced.dismissDuration, regular.dismissDuration)
    }

    func testTrayRemainsAboveNormalWindowsAtEveryInteractionStage() {
        let restingLevel = TrayWindowLevelPolicy.level(receivingExternalDrag: false)
        let receivingLevel = TrayWindowLevelPolicy.level(receivingExternalDrag: true)

        XCTAssertEqual(restingLevel, receivingLevel)
        XCTAssertGreaterThan(restingLevel.rawValue, NSWindow.Level.modalPanel.rawValue)
    }

    @MainActor
    func testBorderlessTrayCanReceiveClicksWithoutBecomingMainWindow() {
        let panel = InteractiveTrayPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        XCTAssertTrue(panel.canBecomeKey)
        XCTAssertFalse(panel.canBecomeMain)
    }

    @MainActor
    func testHostingViewDoesNotImposeStaleExpandedMinimumSize() {
        let hostingView = FirstMouseHostingView(rootView: EmptyView())
        hostingView.sizingOptions = [.intrinsicContentSize]

        XCTAssertTrue(hostingView.sizingOptions.contains(.intrinsicContentSize))
        XCTAssertFalse(hostingView.sizingOptions.contains(.minSize))
        XCTAssertFalse(hostingView.sizingOptions.contains(.maxSize))
        XCTAssertTrue(hostingView.acceptsFirstMouse(for: nil))
    }

    @MainActor
    func testPanelAndRenderedContentStayInSyncAcrossRepeatedExpandAndCollapse() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let firstURL = temporaryDirectory.appendingPathComponent("uno.png")
        let secondURL = temporaryDirectory.appendingPathComponent("dos.png")
        try Data([0x01]).write(to: firstURL)
        try Data([0x02]).write(to: secondURL)

        let store = TrayStore()
        store.addFileURLs([firstURL, secondURL])
        let controller = TrayPanelController(store: store)

        for _ in 0..<2 {
            controller.setExpanded(true)
            XCTAssertTrue(store.isExpanded)
            XCTAssertTrue(controller.renderedIsExpanded)
            XCTAssertEqual(controller.presentationSize, TrayPanelLayout.size(itemCount: 2, isExpanded: true))

            controller.setExpanded(false)
            XCTAssertFalse(store.isExpanded)
            XCTAssertFalse(controller.renderedIsExpanded)
            XCTAssertEqual(controller.presentationSize, TrayPanelLayout.size(itemCount: 2, isExpanded: false))
        }
    }
}
