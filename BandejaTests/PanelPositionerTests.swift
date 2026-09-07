import AppKit
import SwiftUI
import XCTest
@testable import Bandeja

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
        XCTAssertEqual(thirtyTwoItems, CGSize(width: 264, height: 264))

        let expanded = TrayPanelLayout.size(itemCount: 32, isExpanded: true)
        XCTAssertEqual(expanded.width, 520)
        XCTAssertEqual(expanded.height, 570, "La cuadrícula debe usar desplazamiento en lugar de salir de pantalla")
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
}
