import AppKit
import Quartz
import SwiftUI
import UniformTypeIdentifiers

struct NativeThumbnailView: NSViewRepresentable {
    let item: TrayItem
    let size: NSSize

    func makeNSView(context: Context) -> PreviewImageView {
        let imageView = PreviewImageView()
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 10
        imageView.layer?.masksToBounds = true
        imageView.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.055).cgColor
        return imageView
    }

    func updateNSView(_ imageView: PreviewImageView, context: Context) {
        guard imageView.representedID != item.id else { return }
        imageView.representedID = item.id
        imageView.image = item.displayImage

        guard case let .file(url) = item.content else { return }
        let requestedID = item.id
        let scale = imageView.window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        NativeThumbnailLoader.shared.loadThumbnail(for: url, size: size, scale: scale) { [weak imageView] image in
            guard imageView?.representedID == requestedID else { return }
            imageView?.image = image
        }
    }
}

enum AspectFitLayout {
    static func rect(for contentSize: CGSize, in bounds: CGRect) -> CGRect {
        guard contentSize.width > 0,
              contentSize.height > 0,
              bounds.width > 0,
              bounds.height > 0 else { return .zero }

        let scale = min(bounds.width / contentSize.width, bounds.height / contentSize.height)
        let fittedSize = CGSize(width: contentSize.width * scale, height: contentSize.height * scale)
        return CGRect(
            x: bounds.midX - fittedSize.width / 2,
            y: bounds.midY - fittedSize.height / 2,
            width: fittedSize.width,
            height: fittedSize.height
        )
    }
}

final class PreviewImageView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    var representedID: UUID?
    var image: NSImage? {
        didSet { needsDisplay = true }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let image else { return }

        let destination = AspectFitLayout.rect(for: image.size, in: bounds.insetBy(dx: 3, dy: 3))
        image.draw(
            in: destination,
            from: .zero,
            operation: .sourceOver,
            fraction: 1,
            respectFlipped: true,
            hints: [.interpolation: NSImageInterpolation.high]
        )
    }
}

struct CompactDragSourceView: NSViewRepresentable {
    @ObservedObject var store: TrayStore
    let items: [TrayItem]
    let onBegan: () -> Void
    let onCompleted: (NSDragOperation) -> Void
    let onDoubleClick: () -> Void

    func makeNSView(context: Context) -> CompactDragSourceNSView {
        let view = CompactDragSourceNSView()
        view.setAccessibilityLabel("Arrastrar todos los elementos")
        return view
    }

    func updateNSView(_ view: CompactDragSourceNSView, context: Context) {
        view.store = store
        view.items = items
        view.onBegan = onBegan
        view.onCompleted = onCompleted
        view.onDoubleClick = onDoubleClick
    }
}

final class CompactDragSourceNSView: NSView, NSDraggingSource {
    weak var store: TrayStore?
    var items: [TrayItem] = []
    var onBegan: (() -> Void)?
    var onCompleted: ((NSDragOperation) -> Void)?
    var onDoubleClick: (() -> Void)?

    private var initialLocation: NSPoint?
    private var beganDragging = false
    private var sourceOperations: NSDragOperation = []
    private var promiseDelegates: [ImagePromiseDelegate] = []
    private let dragPreview = TrayDragPreviewSession()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL, .png, .tiff])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL, .png, .tiff])
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        validatedOperation(for: sender)
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        validatedOperation(for: sender)
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        store?.isDropTargeted = false
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        store?.isDropTargeted = false
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard !validatedOperation(for: sender).isEmpty else { return false }
        // AppKit inspects this between prepare and perform, not afterwards.
        sender.animatesToDestination = false
        return true
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let store else { return false }
        defer { store.isDropTargeted = false }
        guard !isInternalDrag(sender) else { return false }
        return TrayPasteboardImporter.importDrop(sender, into: store, destination: self)
    }

    override func mouseDown(with event: NSEvent) {
        initialLocation = convert(event.locationInWindow, from: nil)
        beganDragging = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard !beganDragging, !items.isEmpty, let initialLocation else { return }
        let location = convert(event.locationInWindow, from: nil)
        guard hypot(location.x - initialLocation.x, location.y - initialLocation.y) >= 4 else { return }

        let draggingItems = makeDraggingItems(at: location)
        guard !draggingItems.isEmpty else { return }
        sourceOperations = TrayDragPolicy.operations(for: items)
        beganDragging = true
        onBegan?()

        let session = beginDraggingSession(with: draggingItems, event: event, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = true
        dragPreview.begin(session, items: items, scale: window?.backingScaleFactor ?? 2)
    }

    override func mouseUp(with event: NSEvent) {
        if !beganDragging, event.clickCount == 2 {
            onDoubleClick?()
        }
        initialLocation = nil
    }

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        sourceOperations
    }

    private func validatedOperation(for sender: NSDraggingInfo) -> NSDragOperation {
        guard let store, !isInternalDrag(sender) else {
            store?.isDropTargeted = false
            return []
        }
        store.isDropTargeted = TrayPasteboardImporter.canImport(from: sender.draggingPasteboard)
        return store.isDropTargeted ? .copy : []
    }

    private func isInternalDrag(_ sender: NSDraggingInfo) -> Bool {
        guard let sourceView = sender.draggingSource as? NSView else { return false }
        return sourceView.window === window
    }

    func ignoreModifierKeys(for session: NSDraggingSession) -> Bool {
        false
    }

    func draggingSession(
        _ session: NSDraggingSession,
        endedAt screenPoint: NSPoint,
        operation: NSDragOperation
    ) {
        dragPreview.end()
        promiseDelegates.removeAll()
        sourceOperations = []
        initialLocation = nil
        beganDragging = false
        onCompleted?(operation)
    }

    private func makeDraggingItems(at location: NSPoint) -> [NSDraggingItem] {
        promiseDelegates.removeAll()

        return items.enumerated().compactMap { index, item in
            let writer: NSPasteboardWriting
            switch item.content {
            case let .file(url):
                writer = url as NSURL
            case let .image(data, _):
                let delegate = ImagePromiseDelegate(data: data, fileName: item.name)
                promiseDelegates.append(delegate)
                writer = NSFilePromiseProvider(fileType: UTType.png.identifier, delegate: delegate)
            }

            let draggingItem = NSDraggingItem(pasteboardWriter: writer)
            let scale = window?.backingScaleFactor ?? 2
            let preview = item.fileURL.flatMap { NativeThumbnailLoader.shared.cachedThumbnail(for: $0, scale: scale) }
                ?? item.displayImage
            let badgeIndex = items.firstIndex(where: { $0.fileURL != nil })
            let image = DragPreviewRenderer.image(preview: preview,
                showTransferBadge: index == badgeIndex && DragPreviewRenderer.showsTransferBadge(for: item, modifiers: NSEvent.modifierFlags),
                scale: scale)
            let size = image.size
            let stagger = CGFloat(min(index, 3)) * 4
            let frame = NSRect(
                x: location.x - size.width / 2 + stagger,
                y: location.y - size.height / 2 - stagger,
                width: size.width,
                height: size.height
            )
            draggingItem.setDraggingFrame(frame, contents: image)
            return draggingItem
        }
    }

}

struct TrayActionsButton: NSViewRepresentable {
    let items: [TrayItem]
    var onShared: (Set<UUID>) -> Void = { _ in }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSButton {
        let symbol = NSImage(systemSymbolName: "chevron.down", accessibilityDescription: "Acciones")?
            .withSymbolConfiguration(.init(pointSize: 13, weight: .semibold))
            ?? NSImage()
        let button = TrayActionNSButton(
            image: symbol,
            target: context.coordinator,
            action: #selector(Coordinator.showMenu(_:))
        )
        button.title = ""
        button.imagePosition = .imageOnly
        button.isBordered = false
        button.contentTintColor = NSColor.labelColor.withAlphaComponent(0.78)
        button.toolTip = "Acciones y compartir"
        button.setAccessibilityLabel("Acciones y compartir")
        context.coordinator.button = button
        return button
    }

    func updateNSView(_ button: NSButton, context: Context) {
        context.coordinator.items = items
        context.coordinator.onShared = onShared
        button.isEnabled = !items.isEmpty
    }

    @MainActor
    final class Coordinator: NSObject {
        var items: [TrayItem] = []
        var onShared: (Set<UUID>) -> Void = { _ in }
        private var sharingSession: TraySharingSession?
        weak var button: NSButton?
        private var sharingServices: [NSSharingService] = []
        private var sharingPicker: NSSharingServicePicker?

        @objc func showMenu(_ sender: NSButton) {
            guard !items.isEmpty else { return }
            let menu = NSMenu()
            menu.autoenablesItems = false

            let fileURLs = items.compactMap(\.fileURL)
            if let firstURL = fileURLs.first {
                let openWithItem = NSMenuItem(title: "Abrir con", action: nil, keyEquivalent: "")
                openWithItem.image = NSImage(systemSymbolName: "app.badge", accessibilityDescription: nil)
                openWithItem.submenu = makeOpenWithMenu(for: firstURL)
                menu.addItem(openWithItem)

                let revealItem = NSMenuItem(
                    title: fileURLs.count == 1 ? "Mostrar en Finder" : "Mostrar en Finder",
                    action: #selector(showInFinder(_:)),
                    keyEquivalent: ""
                )
                revealItem.target = self
                revealItem.image = NSImage(systemSymbolName: "folder", accessibilityDescription: nil)
                menu.addItem(revealItem)

                let quickLookItem = NSMenuItem(
                    title: "Vista rápida",
                    action: #selector(showQuickLook(_:)),
                    keyEquivalent: ""
                )
                quickLookItem.target = self
                quickLookItem.image = NSImage(systemSymbolName: "eye", accessibilityDescription: nil)
                menu.addItem(quickLookItem)
                menu.addItem(.separator())
            }

            addSharingItems(to: menu)
            menu.popUp(positioning: nil, at: NSPoint(x: sender.bounds.minX, y: sender.bounds.minY - 4), in: sender)
        }

        private func makeOpenWithMenu(for url: URL) -> NSMenu {
            let submenu = NSMenu()
            let applications = NSWorkspace.shared.urlsForApplications(toOpen: url)
                .sorted { appDisplayName($0).localizedStandardCompare(appDisplayName($1)) == .orderedAscending }

            for applicationURL in applications.prefix(14) {
                let item = NSMenuItem(
                    title: appDisplayName(applicationURL),
                    action: #selector(openWithApplication(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = applicationURL
                item.image = NSWorkspace.shared.icon(forFile: applicationURL.path)
                item.image?.size = NSSize(width: 16, height: 16)
                submenu.addItem(item)
            }

            if submenu.items.isEmpty {
                let unavailable = NSMenuItem(title: "No hay aplicaciones compatibles", action: nil, keyEquivalent: "")
                unavailable.isEnabled = false
                submenu.addItem(unavailable)
            }
            return submenu
        }

        private func addSharingItems(to menu: NSMenu) {
            let values = shareableValues
            let session = TraySharingSession(items: items, onShared: onShared)
            sharingSession = session
            sharingServices = preferredSharingServices(for: values)

            for (index, service) in sharingServices.enumerated() {
                let item = NSMenuItem(
                    title: service.title,
                    action: #selector(performSharingService(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.tag = index
                item.image = service.image
                menu.addItem(item)
            }

            let picker = NSSharingServicePicker(items: values)
            picker.delegate = session
            sharingPicker = picker
            let moreItem = picker.standardShareMenuItem
            moreItem.title = sharingServices.isEmpty ? "Compartir…" : "Más opciones…"
            menu.addItem(moreItem)
        }

        private func preferredSharingServices(for values: [Any]) -> [NSSharingService] {
            guard !values.isEmpty else { return [] }
            let preferredNames: [NSSharingService.Name] = [.sendViaAirDrop, .composeEmail, .composeMessage]
            var result: [NSSharingService] = []

            for name in preferredNames {
                if let service = NSSharingService(named: name), service.canPerform(withItems: values) {
                    result.append(service)
                }
            }
            return result
        }

        private var shareableValues: [Any] {
            items.map { item in
                switch item.content {
                case let .file(url): return url as NSURL
                case let .image(_, image): return image
                }
            }
        }

        private func appDisplayName(_ url: URL) -> String {
            (try? url.resourceValues(forKeys: [.localizedNameKey]).localizedName)
                ?? url.deletingPathExtension().lastPathComponent
        }

        @objc private func openWithApplication(_ sender: NSMenuItem) {
            guard let applicationURL = sender.representedObject as? URL else { return }
            let configuration = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.open(
                items.compactMap(\.fileURL),
                withApplicationAt: applicationURL,
                configuration: configuration
            )
        }

        @objc private func showInFinder(_ sender: NSMenuItem) {
            NSWorkspace.shared.activateFileViewerSelecting(items.compactMap(\.fileURL))
        }

        @objc private func showQuickLook(_ sender: NSMenuItem) {
            QuickLookPreviewController.shared.show(items.compactMap(\.fileURL))
        }

        @objc private func performSharingService(_ sender: NSMenuItem) {
            guard sharingServices.indices.contains(sender.tag) else { return }
            sharingSession?.perform(sharingServices[sender.tag], values: shareableValues)
        }

    }
}

private final class TrayActionNSButton: NSButton {
    private var trackingAreaReference: NSTrackingArea?
    private var isHovered = false {
        didSet { updateAppearance() }
    }

    override func layout() {
        super.layout()
        wantsLayer = true
        layer?.cornerRadius = bounds.height / 2
        updateAppearance()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingAreaReference {
            removeTrackingArea(trackingAreaReference)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingAreaReference = area
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
    }

    private func updateAppearance() {
        layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(isHovered ? 0.17 : 0.11).cgColor
    }
}

@MainActor
final class QuickLookPreviewController: NSObject, @MainActor QLPreviewPanelDataSource {
    static let shared = QuickLookPreviewController()

    private var urls: [URL] = []

    func show(_ urls: [URL]) {
        guard !urls.isEmpty, let panel = QLPreviewPanel.shared() else { return }
        self.urls = urls
        panel.dataSource = self
        panel.reloadData()
        panel.makeKeyAndOrderFront(nil)
    }

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        urls.count
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        guard urls.indices.contains(index) else { return nil }
        return urls[index] as NSURL
    }
}
