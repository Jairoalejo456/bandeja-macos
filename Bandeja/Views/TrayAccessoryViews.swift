import AppKit
import Quartz
import SwiftUI
import UniformTypeIdentifiers

struct NativeThumbnailView: NSViewRepresentable {
    let item: TrayItem
    let size: NSSize

    func makeNSView(context: Context) -> PreviewImageView {
        let imageView = PreviewImageView()
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.imageAlignment = .alignCenter
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 10
        imageView.layer?.masksToBounds = true
        imageView.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.055).cgColor
        return imageView
    }

    func updateNSView(_ imageView: PreviewImageView, context: Context) {
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

final class PreviewImageView: NSImageView {
    var representedID: UUID?
}

struct CompactDragSourceView: NSViewRepresentable {
    let items: [TrayItem]
    let onCompleted: (NSDragOperation) -> Void
    let onDoubleClick: () -> Void

    func makeNSView(context: Context) -> CompactDragSourceNSView {
        let view = CompactDragSourceNSView()
        view.setAccessibilityLabel("Arrastrar todos los elementos")
        return view
    }

    func updateNSView(_ view: CompactDragSourceNSView, context: Context) {
        view.items = items
        view.onCompleted = onCompleted
        view.onDoubleClick = onDoubleClick
    }
}

final class CompactDragSourceNSView: NSView, NSDraggingSource {
    var items: [TrayItem] = []
    var onCompleted: ((NSDragOperation) -> Void)?
    var onDoubleClick: (() -> Void)?

    private var initialLocation: NSPoint?
    private var beganDragging = false
    private var promiseDelegates: [ImagePromiseDelegate] = []

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
        beganDragging = true

        let session = beginDraggingSession(with: draggingItems, event: event, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = true
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
        .copy
    }

    func ignoreModifierKeys(for session: NSDraggingSession) -> Bool {
        true
    }

    func draggingSession(
        _ session: NSDraggingSession,
        endedAt screenPoint: NSPoint,
        operation: NSDragOperation
    ) {
        promiseDelegates.removeAll()
        initialLocation = nil
        beganDragging = false
        if !operation.isEmpty {
            onCompleted?(operation)
        }
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
            let image = item.displayImage
            let size = fittedSize(for: image.size, maximum: NSSize(width: 88, height: 72))
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

    private func fittedSize(for source: NSSize, maximum: NSSize) -> NSSize {
        guard source.width > 0, source.height > 0 else { return maximum }
        let scale = min(maximum.width / source.width, maximum.height / source.height, 1)
        return NSSize(width: max(36, source.width * scale), height: max(36, source.height * scale))
    }
}

struct TrayActionsButton: NSViewRepresentable {
    let items: [TrayItem]

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
        button.isEnabled = !items.isEmpty
    }

    @MainActor
    final class Coordinator: NSObject {
        var items: [TrayItem] = []
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
            sharingServices[sender.tag].perform(withItems: shareableValues)
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
