import AppKit
import Combine
import QuartzCore
import SwiftUI

@MainActor
final class TrayPanelController {
    private let store: TrayStore
    private let settings: AppSettings
    private let panel: NSPanel
    private var itemSubscription: AnyCancellable?
    private var emptyDismissWorkItem: DispatchWorkItem?

    init(store: TrayStore, settings: AppSettings? = nil) {
        self.store = store
        self.settings = settings ?? .shared

        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: NSSize(width: 264, height: 180)),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isReleasedWhenClosed = false
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.animationBehavior = .utilityWindow
        panel.isMovable = false
        panel.title = "Bandeja"
        panel.setAccessibilityLabel("Bandeja temporal de archivos")

        let rootView = TrayView(
            store: store,
            settings: self.settings,
            onClose: { [weak self] in self?.closeAndClear() },
            onExternalDragCompleted: { [weak self] operation in
                self?.completeExternalDrag(operation)
            }
        )
        panel.contentView = TrayDropContainerView(rootView: rootView, store: store)

        store.onBecameEmpty = { [weak self] in
            self?.hide()
        }
        itemSubscription = Publishers.CombineLatest(
            store.$items.map(\.count).removeDuplicates(),
            store.$isExpanded.removeDuplicates()
        )
            .sink { [weak self] count, isExpanded in
                self?.resize(forItemCount: count, isExpanded: isExpanded)
                if count > 0 {
                    self?.emptyDismissWorkItem?.cancel()
                    self?.emptyDismissWorkItem = nil
                }
            }
    }

    var isVisible: Bool { panel.isVisible }

    func showNearCursor(
        _ cursor: CGPoint = NSEvent.mouseLocation,
        emptyDismissAfter: TimeInterval = 15
    ) {
        resize(forItemCount: store.items.count, isExpanded: store.isExpanded, animated: false)
        positionPanel(near: cursor)

        if !panel.isVisible {
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.16
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().alphaValue = 1
            }
        } else {
            panel.orderFrontRegardless()
        }

        if store.items.isEmpty {
            scheduleEmptyDismissal(after: emptyDismissAfter)
        }
    }

    func hide() {
        emptyDismissWorkItem?.cancel()
        emptyDismissWorkItem = nil
        guard panel.isVisible else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.12
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak panel = panel] in
            panel?.orderOut(nil)
            panel?.alphaValue = 1
        })
    }

    func dragDidEnd() {
        guard store.items.isEmpty else { return }
        scheduleEmptyDismissal(after: 0.2)
    }

    func closeAndClear() {
        if store.items.isEmpty {
            hide()
        } else {
            store.clear()
        }
    }

    func completeExternalDrag(_ operation: NSDragOperation) {
        guard !operation.isEmpty, !store.items.isEmpty else { return }
        store.clear()
    }

    private func scheduleEmptyDismissal(after delay: TimeInterval) {
        emptyDismissWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.store.items.isEmpty else { return }
            self.hide()
        }
        emptyDismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func resize(forItemCount count: Int, isExpanded: Bool, animated: Bool = true) {
        let targetSize = TrayPanelLayout.size(itemCount: count, isExpanded: isExpanded)

        var frame = panel.frame
        guard abs(frame.width - targetSize.width) > 0.5 || abs(frame.height - targetSize.height) > 0.5 else { return }
        let centerX = frame.midX
        let top = frame.maxY
        frame.size = targetSize
        frame.origin.x = centerX - targetSize.width / 2
        frame.origin.y = top - targetSize.height
        frame = clampedFrame(frame)
        panel.setFrame(frame, display: true, animate: animated && panel.isVisible)
    }

    private func positionPanel(near cursor: CGPoint) {
        let screen = NSScreen.screens.first(where: { $0.frame.contains(cursor) }) ?? NSScreen.main
        guard let visibleFrame = screen?.visibleFrame.insetBy(dx: 10, dy: 10) else { return }
        let origin = PanelPositioner.origin(near: cursor, panelSize: panel.frame.size, visibleFrame: visibleFrame)
        panel.setFrameOrigin(origin)
    }

    private func clampedFrame(_ proposedFrame: NSRect) -> NSRect {
        let relevantScreen = NSScreen.screens.first(where: { $0.frame.intersects(proposedFrame) }) ?? NSScreen.main
        guard let visible = relevantScreen?.visibleFrame.insetBy(dx: 10, dy: 10) else { return proposedFrame }

        var frame = proposedFrame
        frame.origin.x = min(max(frame.origin.x, visible.minX), visible.maxX - frame.width)
        frame.origin.y = min(max(frame.origin.y, visible.minY), visible.maxY - frame.height)
        return frame
    }
}

struct TrayPanelLayout {
    static func size(itemCount: Int, isExpanded: Bool) -> NSSize {
        guard isExpanded else {
            return NSSize(width: 264, height: itemCount == 0 ? 180 : 264)
        }

        let rows = max(1, Int(ceil(Double(itemCount) / 4.0)))
        let height = min(CGFloat(570), max(CGFloat(248), CGFloat(rows * 116 + 96)))
        return NSSize(width: 520, height: height)
    }
}

private final class TrayDropContainerView: NSView {
    private let store: TrayStore

    init(rootView: TrayView, store: TrayStore) {
        self.store = store
        super.init(frame: .zero)
        registerForDraggedTypes([.fileURL, .png, .tiff])

        let hostingView = NSHostingView(rootView: rootView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: topAnchor),
            hostingView.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: trailingAnchor),
            hostingView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        validatedOperation(for: sender)
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        validatedOperation(for: sender)
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        store.isDropTargeted = false
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        store.isDropTargeted = false
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        !validatedOperation(for: sender).isEmpty
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        defer { store.isDropTargeted = false }
        guard !isInternalDrag(sender) else { return false }
        return TrayPasteboardImporter.importItems(from: sender.draggingPasteboard, into: store) > 0
    }

    private func validatedOperation(for sender: NSDraggingInfo) -> NSDragOperation {
        guard !isInternalDrag(sender) else {
            store.isDropTargeted = false
            return []
        }
        store.isDropTargeted = TrayPasteboardImporter.canImport(from: sender.draggingPasteboard)
        return store.isDropTargeted ? .copy : []
    }

    private func isInternalDrag(_ sender: NSDraggingInfo) -> Bool {
        guard let sourceView = sender.draggingSource as? NSView else { return false }
        return sourceView.window === window
    }
}

struct PanelPositioner {
    static func origin(near cursor: CGPoint, panelSize: CGSize, visibleFrame: CGRect) -> CGPoint {
        var x = cursor.x + 20
        if x + panelSize.width > visibleFrame.maxX {
            x = cursor.x - panelSize.width - 20
        }

        var y = cursor.y - panelSize.height - 20
        if y < visibleFrame.minY {
            y = cursor.y + 20
        }

        return CGPoint(
            x: min(max(x, visibleFrame.minX), visibleFrame.maxX - panelSize.width),
            y: min(max(y, visibleFrame.minY), visibleFrame.maxY - panelSize.height)
        )
    }
}
