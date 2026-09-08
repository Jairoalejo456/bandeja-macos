import AppKit
import Combine
import SwiftUI

final class InteractiveTrayPanel: NSPanel {
    // Borderless panels do not reliably become key by default. SwiftUI controls
    // can consequently stop receiving clicks while another app owns the focus.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class TrayPanelController {
    private let store: TrayStore
    private let settings: AppSettings
    private let visualState = TrayVisualState()
    private let panel: NSPanel
    private var dropContainerView: TrayDropContainerView!
    private var itemSubscription: AnyCancellable?
    private var dropTargetSubscription: AnyCancellable?
    private var emptyDismissWorkItem: DispatchWorkItem?
    private var animatedDismissWorkItem: DispatchWorkItem?
    private var isReceivingExternalDrag = false
    private var lastItemCount = 0
    private var visualAnimationGeneration = 0

    init(store: TrayStore, settings: AppSettings? = nil) {
        self.store = store
        self.settings = settings ?? .shared

        panel = InteractiveTrayPanel(
            contentRect: NSRect(origin: .zero, size: NSSize(width: 236, height: 158)),
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
        panel.becomesKeyOnlyIfNeeded = false
        panel.acceptsMouseMovedEvents = true
        panel.ignoresMouseEvents = false
        panel.animationBehavior = .utilityWindow
        panel.isMovable = true
        panel.isMovableByWindowBackground = false
        panel.title = "MiniTray"
        panel.setAccessibilityLabel("MiniTray temporal de archivos")
        panel.contentMinSize = .zero
        panel.contentMaxSize = NSSize(width: 2_000, height: 2_000)

        let rootView = TrayView(
            store: store,
            settings: self.settings,
            visualState: visualState,
            isExpanded: store.isExpanded,
            onClose: { [weak self] in self?.closeAndClear() },
            onExpand: { [weak self] in self?.setExpanded(true) },
            onCollapse: { [weak self] in self?.setExpanded(false) },
            onExternalDragBegan: { [weak self] in self?.beginExternalDrag() },
            onExternalDragCompleted: { [weak self] operation in
                self?.completeExternalDrag(operation)
            }
        )
        let dropContainerView = TrayDropContainerView(rootView: rootView, store: store)
        self.dropContainerView = dropContainerView
        panel.contentView = dropContainerView

        store.onBecameEmpty = { [weak self] in
            self?.hide()
        }
        itemSubscription = Publishers.CombineLatest(
            store.$items.map(\.count).removeDuplicates(),
            store.$isExpanded.removeDuplicates()
        )
            .sink { [weak self] count, isExpanded in
                guard let self else { return }
                self.resize(forItemCount: count, isExpanded: isExpanded)
                // @Published emits before SwiftUI has necessarily committed its
                // new branch. Refresh explicitly on the next main-loop turn so
                // the rendered hierarchy always matches the AppKit panel size.
                DispatchQueue.main.async { [weak self] in
                    self?.refreshRootView()
                }
                if count > 0 {
                    self.emptyDismissWorkItem?.cancel()
                    self.emptyDismissWorkItem = nil
                }
                if count > self.lastItemCount, self.panel.isVisible {
                    self.animateDropConfirmation()
                }
                self.lastItemCount = count
            }

        dropTargetSubscription = store.$isDropTargeted
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.updateWindowLevel()
            }
    }

    var isVisible: Bool { panel.isVisible }
    var presentationSize: NSSize { panel.frame.size }
    var renderedIsExpanded: Bool { dropContainerView.renderedIsExpanded }

    func containsScreenPoint(_ point: CGPoint) -> Bool {
        panel.isVisible && panel.frame.contains(point)
    }

    func showNearCursor(
        _ cursor: CGPoint = NSEvent.mouseLocation,
        emptyDismissAfter: TimeInterval = 15,
        receivingExternalDrag: Bool = false
    ) {
        let wasVisible = panel.isVisible
        animatedDismissWorkItem?.cancel()
        animatedDismissWorkItem = nil
        isReceivingExternalDrag = receivingExternalDrag
        synchronizePresentation()
        positionPanel(near: cursor)
        updateWindowLevel()

        // AppKit can defer animator-backed changes while another app owns the drag
        // session. Restore mouse handling and visibility synchronously so a stale
        // transition can never leave an unresponsive panel on screen.
        panel.ignoresMouseEvents = false
        panel.alphaValue = 1
        resetVisualLayer()
        panel.orderFrontRegardless()
        wasVisible ? animateAttention() : animateAppearance()

        if store.items.isEmpty {
            scheduleEmptyDismissal(after: emptyDismissAfter)
        }
    }

    func hide(animated: Bool = true) {
        emptyDismissWorkItem?.cancel()
        emptyDismissWorkItem = nil
        guard panel.isVisible else { return }
        guard animatedDismissWorkItem == nil else { return }

        isReceivingExternalDrag = false
        panel.ignoresMouseEvents = true
        updateWindowLevel()

        let profile = motionProfile
        guard animated else {
            panel.orderOut(nil)
            resetAfterDismissal()
            return
        }

        animateDismissal()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.panel.orderOut(nil)
            self.animatedDismissWorkItem = nil
            self.resetAfterDismissal()
        }
        animatedDismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + profile.dismissDuration, execute: workItem)
    }

    func dragDidEnd() {
        isReceivingExternalDrag = false
        updateWindowLevel()
        guard store.items.isEmpty else { return }
        scheduleEmptyDismissal(after: 0.2)
    }

    func closeAndClear() {
        hide()
        if !store.items.isEmpty {
            store.clear()
        }
    }

    func beginExternalDrag() {
        store.beginExternalDrag()
        refreshRootView()
        panel.displayIfNeeded()
    }

    func completeExternalDrag(_ operation: NSDragOperation) {
        store.endExternalDrag()
        refreshRootView()
        guard !operation.isEmpty, !store.items.isEmpty else {
            animateCancelledDrag()
            return
        }
        hide()
        store.clear()
    }

    func setExpanded(_ isExpanded: Bool) {
        if isExpanded {
            store.expand()
        } else {
            store.collapse()
        }
        synchronizePresentation()
        animatePresentationChange(expanding: isExpanded)
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

    private func resize(forItemCount count: Int, isExpanded: Bool) {
        let targetSize = TrayPanelLayout.size(itemCount: count, isExpanded: isExpanded)

        var frame = panel.frame
        guard abs(frame.width - targetSize.width) > 0.5 || abs(frame.height - targetSize.height) > 0.5 else { return }
        let centerX = frame.midX
        let top = frame.maxY
        frame.size = targetSize
        frame.origin.x = centerX - targetSize.width / 2
        frame.origin.y = top - targetSize.height
        frame = clampedFrame(frame)

        // NSHostingView can otherwise retain the expanded view's minimum width
        // after collapsing. Keep the WindowServer frame and the SwiftUI hit-test
        // tree in lockstep; an interrupted animation must never leave an invisible
        // expanded window around the compact tray.
        panel.contentMinSize = .zero
        panel.setFrame(frame, display: true, animate: false)
        panel.contentView?.layoutSubtreeIfNeeded()
    }

    private func synchronizePresentation() {
        resize(forItemCount: store.items.count, isExpanded: store.isExpanded)
        refreshRootView()
    }

    private func refreshRootView() {
        dropContainerView.update(rootView: makeRootView())
        panel.contentView?.layoutSubtreeIfNeeded()
        panel.displayIfNeeded()
    }

    private func makeRootView() -> TrayView {
        TrayView(
            store: store,
            settings: settings,
            visualState: visualState,
            isExpanded: store.isExpanded,
            onClose: { [weak self] in self?.closeAndClear() },
            onExpand: { [weak self] in self?.setExpanded(true) },
            onCollapse: { [weak self] in self?.setExpanded(false) },
            onExternalDragBegan: { [weak self] in self?.beginExternalDrag() },
            onExternalDragCompleted: { [weak self] operation in
                self?.completeExternalDrag(operation)
            }
        )
    }

    private var motionProfile: TrayMotionProfile {
        TrayMotionProfile(reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
    }

    private func updateWindowLevel() {
        panel.level = TrayWindowLevelPolicy.level(
            receivingExternalDrag: isReceivingExternalDrag || store.isDropTargeted
        )
    }

    private func resetAfterDismissal() {
        panel.alphaValue = 1
        panel.ignoresMouseEvents = false
        resetVisualLayer()
    }

    private func resetVisualLayer() {
        visualAnimationGeneration += 1
        panel.alphaValue = 1
        setVisualState(opacity: 1, scale: 1)
    }

    private func animateAppearance() {
        let profile = motionProfile
        animateVisual(
            fromOpacity: 0,
            fromScale: profile.reduceMotion ? 1 : 0.965,
            toOpacity: 1,
            toScale: 1,
            duration: profile.appearanceDuration
        )
    }

    private func animateAttention() {
        let profile = motionProfile
        animateVisual(
            fromOpacity: profile.reduceMotion ? 0.96 : 0.90,
            fromScale: profile.reduceMotion ? 1 : 1.018,
            toOpacity: 1,
            toScale: 1,
            duration: profile.attentionDuration
        )
    }

    private func animateDropConfirmation() {
        let profile = motionProfile
        animateVisual(
            fromOpacity: profile.reduceMotion ? 0.97 : 0.92,
            fromScale: profile.reduceMotion ? 1 : 1.026,
            toOpacity: 1,
            toScale: 1,
            duration: profile.dropDuration
        )
    }

    private func animatePresentationChange(expanding: Bool) {
        let profile = motionProfile
        animateVisual(
            fromOpacity: profile.reduceMotion ? 0.94 : 0.84,
            fromScale: profile.reduceMotion ? 1 : (expanding ? 0.985 : 1.015),
            toOpacity: 1,
            toScale: 1,
            duration: profile.presentationDuration
        )
    }

    private func animateCancelledDrag() {
        let profile = motionProfile
        animateVisual(
            fromOpacity: profile.reduceMotion ? 0.96 : 0.86,
            fromScale: profile.reduceMotion ? 1 : 0.985,
            toOpacity: 1,
            toScale: 1,
            duration: profile.cancelDuration
        )
    }

    private func animateDismissal() {
        let profile = motionProfile
        animateVisual(
            fromOpacity: visualState.opacity,
            fromScale: visualState.scale,
            toOpacity: 0,
            toScale: profile.reduceMotion ? 1 : 0.97,
            duration: profile.dismissDuration
        )
    }

    private func animateVisual(
        fromOpacity: Double,
        fromScale: CGFloat,
        toOpacity: Double,
        toScale: CGFloat,
        duration: CFTimeInterval
    ) {
        visualAnimationGeneration += 1
        let generation = visualAnimationGeneration
        let frameCount = max(1, Int(ceil(duration * 60)))

        for frame in 0...frameCount {
            let delay = duration * Double(frame) / Double(frameCount)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, generation == self.visualAnimationGeneration else { return }
                let progress = Double(frame) / Double(frameCount)
                let eased = 1 - pow(1 - progress, 3)
                let opacity = fromOpacity + (toOpacity - fromOpacity) * eased
                let scale = fromScale + (toScale - fromScale) * CGFloat(eased)
                self.setVisualState(opacity: opacity, scale: scale)
            }
        }
    }

    private func setVisualState(opacity: Double, scale: CGFloat) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            visualState.opacity = opacity
            visualState.scale = scale
        }
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
            return NSSize(width: 236, height: itemCount == 0 ? 158 : 236)
        }

        let rows = max(1, Int(ceil(Double(itemCount) / 4.0)))
        let height = min(CGFloat(540), max(CGFloat(232), CGFloat(rows * 108 + 88)))
        return NSSize(width: 480, height: height)
    }
}

struct TrayMotionProfile: Equatable {
    let reduceMotion: Bool

    var appearanceDuration: CFTimeInterval { reduceMotion ? 0.08 : 0.18 }
    var attentionDuration: CFTimeInterval { reduceMotion ? 0.08 : 0.20 }
    var dropDuration: CFTimeInterval { reduceMotion ? 0.08 : 0.24 }
    var presentationDuration: CFTimeInterval { reduceMotion ? 0.10 : 0.20 }
    var cancelDuration: CFTimeInterval { reduceMotion ? 0.08 : 0.18 }
    var dismissDuration: CFTimeInterval { reduceMotion ? 0.08 : 0.15 }
}

@MainActor
final class TrayVisualState: ObservableObject {
    @Published var opacity: Double = 1
    @Published var scale: CGFloat = 1
}

enum TrayWindowLevelPolicy {
    static func level(receivingExternalDrag: Bool) -> NSWindow.Level {
        guard receivingExternalDrag else { return .floating }
        return NSWindow.Level(rawValue: NSWindow.Level.modalPanel.rawValue + 1)
    }
}

private final class TrayDropContainerView: NSView {
    private let store: TrayStore
    private let hostingView: FirstMouseHostingView<TrayView>
    private(set) var renderedIsExpanded: Bool

    init(rootView: TrayView, store: TrayStore) {
        self.store = store
        self.hostingView = FirstMouseHostingView(rootView: rootView)
        self.renderedIsExpanded = rootView.isExpanded
        super.init(frame: .zero)
        registerForDraggedTypes([.fileURL, .png, .tiff])

        // Keep SwiftUI's visual intrinsic size, but never let its transient
        // expanded minimum/maximum sizes constrain the surrounding NSPanel.
        hostingView.sizingOptions = [.intrinsicContentSize]
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: topAnchor),
            hostingView.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: trailingAnchor),
            hostingView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    func update(rootView: TrayView) {
        renderedIsExpanded = rootView.isExpanded
        hostingView.rootView = rootView
        hostingView.invalidateIntrinsicContentSize()
        hostingView.needsLayout = true
        needsLayout = true
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

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
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

final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
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
