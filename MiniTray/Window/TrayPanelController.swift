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
    private let motion: TrayMotionClock
    private let reduceMotionOverride: Bool?
    private let panel: NSPanel
    private var dropContainerView: TrayDropContainerView!
    private var itemSubscription: AnyCancellable?
    private var dropTargetSubscription: AnyCancellable?
    private var emptyDismissWorkItem: DispatchWorkItem?
    private var isReceivingExternalDrag = false
    private var isDismissing = false
    private var lastItemIDs: Set<UUID> = []
    private var pendingDrop: TrayIncomingDrop?
    private var proxyPanel: NSPanel?
    private var resizeTarget: CGRect?

    init(store: TrayStore, settings: AppSettings? = nil, motionClock: TrayMotionClock? = nil,
         reduceMotion: Bool? = nil) {
        self.store = store
        self.settings = settings ?? .shared
        self.motion = motionClock ?? TrayMotionClock()
        self.reduceMotionOverride = reduceMotion
        panel = InteractiveTrayPanel(
            contentRect: NSRect(origin: .zero, size: NSSize(width: 236, height: 158)),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        panel.isReleasedWhenClosed = false
        panel.isFloatingPanel = true
        panel.level = TrayWindowLevelPolicy.alwaysOnTop
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.acceptsMouseMovedEvents = true
        panel.ignoresMouseEvents = false
        panel.animationBehavior = .none
        panel.isMovable = true
        panel.isMovableByWindowBackground = false
        panel.title = "MiniTray"
        panel.setAccessibilityLabel("MiniTray temporal de archivos")
        panel.contentMinSize = .zero
        panel.contentMaxSize = NSSize(width: 2_000, height: 2_000)
        dropContainerView = TrayDropContainerView(rootView: makeRootView(), store: store)
        panel.contentView = dropContainerView
        store.onBecameEmpty = { [weak self] in self?.hide() }
        store.onAcceptedDrop = { [weak self] drop in
            guard let self else { return }
            // The import is already committed. This context is visual only.
            self.pendingDrop = drop
            if self.isDismissing { self.showNearCursor(drop.screenPoint, receivingExternalDrag: true) }
        }
        itemSubscription = Publishers.CombineLatest(
            store.$items.map { $0.map(\.id) }.removeDuplicates(),
            store.$isExpanded.removeDuplicates()
        ).sink { [weak self] _, _ in
            // @Published emits before mutation. Coalesce multi-file imports on
            // the next turn, then read the committed store, never an old branch.
            DispatchQueue.main.async { [weak self] in self?.reconcileContent() }
        }
        dropTargetSubscription = store.$isDropTargeted.removeDuplicates().sink { [weak self] _ in
            self?.updateWindowLevel()
        }
    }

    var isVisible: Bool { panel.isVisible }
    var presentationSize: NSSize { panel.frame.size }
    var renderedIsExpanded: Bool { dropContainerView.renderedIsExpanded }
    var hasActiveAnimations: Bool { motion.hasWork }
    var isInteractive: Bool { !panel.ignoresMouseEvents }
    var presentationFrame: NSRect { panel.frame }
    var hasIncomingProxy: Bool { proxyPanel != nil }

    func containsScreenPoint(_ point: CGPoint) -> Bool {
        panel.isVisible && panel.frame.contains(point)
    }

    func showNearCursor(
        _ cursor: CGPoint = NSEvent.mouseLocation,
        emptyDismissAfter: TimeInterval = 15,
        receivingExternalDrag: Bool = false
    ) {
        let wasVisible = panel.isVisible && !isDismissing
        cancelMotion()
        lastItemIDs = Set(store.items.map(\.id))
        isReceivingExternalDrag = receivingExternalDrag
        resize(animated: false)
        refreshRootView()
        positionPanel(near: cursor)
        updateWindowLevel()
        panel.ignoresMouseEvents = false
        panel.alphaValue = 1
        panel.orderFrontRegardless()
        runSurface(wasVisible ? TrayMotion.receive(reduced: reducedMotion) : TrayMotion.entrance(reduced: reducedMotion))
        if !wasVisible { runSweep(duration: 0.56) }
        if store.items.isEmpty { scheduleEmptyDismissal(after: emptyDismissAfter) }
    }

    func hide(animated: Bool = true) {
        emptyDismissWorkItem?.cancel()
        emptyDismissWorkItem = nil
        guard panel.isVisible else { return }
        if !animated { finishDismissal(); return }
        guard !isDismissing else { return }
        let pose = visualState.pose
        let expanded = store.isExpanded
        cancelMotion()
        isDismissing = true
        // Freeze only the presentation. Logical references may be cleared now,
        // and the last frame cannot shrink/reflow into an empty tray on exit.
        visualState.retainedItems = store.items
        visualState.retainedExpanded = expanded
        refreshRootView()
        isReceivingExternalDrag = false
        updateWindowLevel()
        runSurface(TrayMotion.exit(from: pose, reduced: reducedMotion)) { [weak self] in
            self?.finishDismissal()
        }
    }

    func dragDidEnd() {
        isReceivingExternalDrag = false
        updateWindowLevel()
        if store.items.isEmpty { scheduleEmptyDismissal(after: 0.2) }
    }

    func closeAndClear() {
        hide()
        store.clear()
    }

    func beginExternalDrag() {
        cancelMotion()
        resize(animated: false)
        store.beginExternalDrag()
        refreshRootView()
    }

    func beginWindowDrag() {
        guard !isDismissing else { return }
        cancelMotion()
        resize(animated: false)
        refreshRootView()
    }

    func completeExternalDrag(_ operation: NSDragOperation) {
        store.endExternalDrag()
        guard !operation.isEmpty, !store.items.isEmpty else {
            refreshRootView()
            runSurface(.between(MotionPose(opacity: 0.86), .identity, duration: 0.12))
            return
        }
        hide()
        store.clear()
    }

    func setExpanded(_ expanded: Bool) {
        guard !isDismissing, !store.items.isEmpty, expanded != store.isExpanded else { return }
        let outgoing = store.isExpanded
        let size = panel.frame.size
        // Rebase from the actual current frame on every reversal.
        motion.cancel("resize")
        motion.cancel("content")
        visualState.outgoingExpanded = panel.isVisible && !reducedMotion ? outgoing : nil
        visualState.outgoingSize = size
        visualState.outgoingOpacity = 1
        expanded ? store.expand() : store.collapse()
        visualState.contentOpacity = panel.isVisible ? 0 : 1
        resize(animated: panel.isVisible)
        refreshRootView()
        guard panel.isVisible else { return }
        let reduced = reducedMotion
        let incomingDuration = reduced ? 0.12 : (expanded ? 0.2 : 0.18)
        let delay = !reduced && expanded ? 0.06 : 0.0
        motion.run("content", duration: max(0.18, incomingDuration + delay)) { [weak self] elapsed in
            guard let self else { return }
            self.visualState.outgoingOpacity = max(0, 1 - elapsed / 0.18)
            self.visualState.contentOpacity = MotionCurve.glide.value(at: max(0, (elapsed - delay) / incomingDuration))
        } completion: { [weak self] in
            self?.visualState.outgoingExpanded = nil
            self?.visualState.contentOpacity = 1
        }
    }

    /// Only a confirmed native share is a completed transfer. Choosing a service
    /// or cancelling its composer must never dismiss/empty the user's files.
    func completeSharing(ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        let currentIDs = Set(store.items.map(\.id))
        guard currentIDs == ids, panel.isVisible, !isDismissing else {
            store.remove(ids: ids)
            return
        }
        cancelMotion()
        isDismissing = true
        visualState.retainedItems = store.items
        visualState.retainedExpanded = store.isExpanded
        let reduced = reducedMotion
        animateItems(store.items, sharing: true, delay: 0)
        runSweep(duration: 0.42)
        runSurface(TrayMotion.shareTray(reduced: reduced), delay: reduced ? 0 : 0.09) { [weak self] in
            self?.finishDismissal()
        }
        store.remove(ids: ids)
    }

    private var reducedMotion: Bool { reduceMotionOverride ?? NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    private func reconcileContent() {
        let ids = Set(store.items.map(\.id))
        let incoming = store.items.filter { !lastItemIDs.contains($0.id) }
        lastItemIDs = ids
        guard !isDismissing else { return }
        if !ids.isEmpty { emptyDismissWorkItem?.cancel(); emptyDismissWorkItem = nil }
        resize(animated: panel.isVisible)
        refreshRootView()
        if !incoming.isEmpty, panel.isVisible {
            let drop = pendingDrop
            pendingDrop = nil
            let absorb = !reducedMotion && drop?.folderImage != nil
            if absorb, let drop { animateFolder(drop) }
            let delay = absorb ? 0.19 : 0
            runSurface(TrayMotion.receive(reduced: reducedMotion), delay: delay)
            animateItems(incoming, sharing: false, delay: delay)
        } else {
            pendingDrop = nil
        }
    }

    private func scheduleEmptyDismissal(after delay: TimeInterval) {
        emptyDismissWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.store.items.isEmpty else { return }
            self.hide()
        }
        emptyDismissWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func resize(animated: Bool) {
        let size = TrayPanelLayout.size(itemCount: store.items.count, isExpanded: store.isExpanded)
        if resizeTarget?.size == size { return }
        let start = panel.frame
        let end = clampedFrame(CGRect(x: start.midX - size.width / 2,
                                      y: start.midY - size.height / 2,
                                      width: size.width, height: size.height))
        motion.cancel("resize")
        resizeTarget = nil
        guard abs(start.width - size.width) > 0.5 || abs(start.height - size.height) > 0.5 else { return }
        guard animated, !reducedMotion else {
            setFrame(end)
            visualState.contentSize = nil
            return
        }
        resizeTarget = end
        visualState.contentSize = CGSize(width: size.width - 16, height: size.height - 16)
        motion.run("resize", duration: 0.3) { [weak self] elapsed in
            self?.setFrame(TrayMotion.frame(from: start, to: end, progress: elapsed / 0.3))
        } completion: { [weak self] in
            guard let self else { return }
            self.setFrame(end)
            self.resizeTarget = nil
            self.visualState.contentSize = nil
            self.refreshRootView()
        }
    }

    private func setFrame(_ frame: CGRect) {
        panel.contentMinSize = .zero
        panel.setFrame(frame, display: true, animate: false)
        panel.contentView?.layoutSubtreeIfNeeded()
    }

    private func refreshRootView() {
        dropContainerView.update(rootView: makeRootView())
        panel.contentView?.layoutSubtreeIfNeeded()
    }

    private func makeRootView() -> TrayView {
        TrayView(store: store, settings: settings, visualState: visualState,
                 isExpanded: visualState.retainedExpanded ?? store.isExpanded,
                 onClose: { [weak self] in self?.closeAndClear() },
                 onExpand: { [weak self] in self?.setExpanded(true) },
                 onCollapse: { [weak self] in self?.setExpanded(false) },
                 onExternalDragBegan: { [weak self] in self?.beginExternalDrag() },
                 onExternalDragCompleted: { [weak self] in self?.completeExternalDrag($0) },
                 onShared: { [weak self] in self?.completeSharing(ids: $0) },
                 onWindowDragBegan: { [weak self] in self?.beginWindowDrag() })
    }

    private func runSurface(_ track: MotionTrack, delay: TimeInterval = 0, completion: @escaping () -> Void = {}) {
        motion.run("surface", duration: track.duration, delay: delay) { [weak self] elapsed in
            self?.visualState.pose = track.pose(at: elapsed)
        } completion: { completion() }
    }

    private func runSweep(duration: TimeInterval) {
        guard !reducedMotion, !NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency else { return }
        motion.run("sweep", duration: duration) { [weak self] elapsed in
            self?.visualState.sweep = elapsed / duration
        } completion: { [weak self] in self?.visualState.sweep = nil }
    }

    private func animateItems(_ items: [TrayItem], sharing: Bool, delay: TimeInterval) {
        let reduced = reducedMotion
        let track = sharing ? TrayMotion.shareItem(reduced: reduced) : TrayMotion.incomingItem(reduced: reduced)
        for (index, item) in items.enumerated() {
            let stagger = reduced ? 0 : TrayMotion.itemDelay(index: index, sharing: sharing)
            motion.run("item-\(item.id)", duration: track.duration, delay: delay + stagger) { [weak self] elapsed in
                self?.visualState.itemPoses[item.id] = track.pose(at: elapsed)
            } completion: { [weak self] in
                if !sharing { self?.visualState.itemPoses.removeValue(forKey: item.id) }
            }
        }
    }

    private func animateFolder(_ drop: TrayIncomingDrop) {
        guard let image = drop.folderImage else { return }
        proxyPanel?.orderOut(nil)
        let state = TrayVisualState()
        let proxy = NSPanel(contentRect: NSRect(x: drop.screenPoint.x - 52, y: drop.screenPoint.y - 48,
                                               width: 104, height: 96),
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        proxy.isReleasedWhenClosed = false
        proxy.backgroundColor = .clear
        proxy.isOpaque = false
        proxy.hasShadow = false
        proxy.ignoresMouseEvents = true
        proxy.level = NSWindow.Level(rawValue: panel.level.rawValue + 1)
        proxy.collectionBehavior = panel.collectionBehavior
        proxy.contentView = NSHostingView(rootView: FolderMotionProxy(image: image, state: state))
        proxyPanel = proxy
        proxy.orderFrontRegardless()
        let targetFrame = resizeTarget ?? panel.frame
        let dx = targetFrame.minX + 46 - drop.screenPoint.x
        let dy = drop.screenPoint.y - targetFrame.midY
        let track = TrayMotion.folder(dx: dx, dy: dy)
        motion.run("folder", duration: track.duration) { elapsed in
            var pose = track.pose(at: elapsed)
            proxy.setFrameOrigin(NSPoint(x: drop.screenPoint.x - 52 + pose.x,
                                         y: drop.screenPoint.y - 48 - pose.y))
            pose.x = 0; pose.y = 0
            state.pose = pose
        } completion: { [weak self, weak proxy] in
            proxy?.orderOut(nil)
            self?.proxyPanel = nil
        }
    }

    private func cancelMotion() {
        motion.cancelAll()
        proxyPanel?.orderOut(nil)
        proxyPanel = nil
        resizeTarget = nil
        isDismissing = false
        visualState.pose = .identity
        visualState.itemPoses = [:]
        visualState.retainedItems = nil
        visualState.retainedExpanded = nil
        visualState.outgoingExpanded = nil
        visualState.contentSize = nil
        visualState.contentOpacity = 1
        visualState.sweep = nil
        panel.ignoresMouseEvents = false
    }

    private func finishDismissal() {
        panel.orderOut(nil)
        cancelMotion()
        // Release render-only references as soon as the last frame is gone.
        resize(animated: false)
        refreshRootView()
    }

    private func updateWindowLevel() {
        panel.level = TrayWindowLevelPolicy.level(receivingExternalDrag: isReceivingExternalDrag || store.isDropTargeted)
    }

    private func positionPanel(near cursor: CGPoint) {
        let screen = NSScreen.screens.first(where: { $0.frame.contains(cursor) }) ?? NSScreen.main
        guard let visible = screen?.visibleFrame.insetBy(dx: 10, dy: 10) else { return }
        panel.setFrameOrigin(PanelPositioner.origin(near: cursor, panelSize: panel.frame.size, visibleFrame: visible))
    }

    private func clampedFrame(_ proposed: NSRect) -> NSRect {
        let screen = NSScreen.screens.first(where: { $0.frame.contains(panel.frame.center) }) ?? NSScreen.main
        guard let visible = screen?.visibleFrame.insetBy(dx: 10, dy: 10) else { return proposed }
        var frame = proposed
        frame.origin.x = min(max(frame.minX, visible.minX), visible.maxX - frame.width)
        frame.origin.y = min(max(frame.minY, visible.minY), visible.maxY - frame.height)
        return frame
    }
}

private extension CGRect {
    var center: CGPoint { CGPoint(x: midX, y: midY) }
}

private struct FolderMotionProxy: View {
    let image: NSImage
    @ObservedObject var state: TrayVisualState
    var body: some View {
        Image(nsImage: image).resizable().aspectRatio(contentMode: .fit)
            .frame(width: 72, height: 72)
            .modifier(MotionPoseModifier(pose: state.pose))
            .frame(width: 104, height: 96)
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

    var appearanceDuration: CFTimeInterval { reduceMotion ? 0.12 : 0.34 }
    var attentionDuration: CFTimeInterval { reduceMotion ? 0.12 : 0.26 }
    var dropDuration: CFTimeInterval { reduceMotion ? 0.12 : 0.26 }
    var presentationDuration: CFTimeInterval { reduceMotion ? 0.12 : 0.30 }
    var cancelDuration: CFTimeInterval { reduceMotion ? 0.12 : 0.18 }
    var dismissDuration: CFTimeInterval { reduceMotion ? 0.12 : 0.20 }
}

enum TrayWindowLevelPolicy {
    static let alwaysOnTop = NSWindow.Level(
        rawValue: NSWindow.Level.modalPanel.rawValue + 1
    )

    static func level(receivingExternalDrag: Bool) -> NSWindow.Level {
        alwaysOnTop
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
        guard !validatedOperation(for: sender).isEmpty else { return false }
        sender.animatesToDestination = false
        return true
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        defer { store.isDropTargeted = false }
        guard !isInternalDrag(sender) else { return false }
        return TrayPasteboardImporter.importDrop(sender, into: store, destination: self)
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
