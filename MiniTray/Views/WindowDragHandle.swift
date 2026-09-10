import AppKit
import SwiftUI

struct WindowDragHandle: NSViewRepresentable {
    var onBegan: () -> Void = {}
    func makeNSView(context: Context) -> NSView {
        WindowDragView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? WindowDragView)?.onBegan = onBegan
    }
}

private final class WindowDragView: NSView {
    var onBegan: () -> Void = {}
    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .openHand)
    }

    override func mouseDown(with event: NSEvent) {
        let dragWindow = window
        onBegan()
        NSCursor.closedHand.push()
        defer { NSCursor.pop() }
        dragWindow?.performDrag(with: event)
    }

    override var acceptsFirstResponder: Bool { false }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}
