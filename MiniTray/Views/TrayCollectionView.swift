import AppKit
import CoreImage
import QuickLookThumbnailing
import SwiftUI
import UniformTypeIdentifiers

struct TrayCollectionView: NSViewRepresentable {
    @ObservedObject var store: TrayStore
    var items: [TrayItem]? = nil
    var itemPoses: [UUID: MotionPose] = [:]
    private var displayItems: [TrayItem] { items ?? store.items }
    let revealInFinderOnDoubleClick: Bool
    let onExternalDragBegan: () -> Void
    let onExternalDragCompleted: (NSDragOperation) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            store: store,
            revealInFinderOnDoubleClick: revealInFinderOnDoubleClick,
            onExternalDragBegan: onExternalDragBegan,
            onExternalDragCompleted: onExternalDragCompleted
        )
    }

    func makeNSView(context: Context) -> NSScrollView {
        let layout = NSCollectionViewFlowLayout()
        layout.itemSize = NSSize(width: 106, height: 104)
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 8
        layout.sectionInset = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)

        let collectionView = DoubleClickCollectionView()
        collectionView.collectionViewLayout = layout
        collectionView.backgroundColors = [.clear]
        collectionView.isSelectable = true
        collectionView.allowsMultipleSelection = true
        collectionView.register(
            TrayCollectionViewItem.self,
            forItemWithIdentifier: TrayCollectionViewItem.identifier
        )
        collectionView.dataSource = context.coordinator
        collectionView.delegate = context.coordinator
        collectionView.onDoubleClick = { [weak coordinator = context.coordinator] indexPath in
            coordinator?.openDoubleClickedItem(at: indexPath)
        }
        collectionView.setDraggingSourceOperationMask([], forLocal: false)
        collectionView.setDraggingSourceOperationMask([], forLocal: true)
        collectionView.registerForDraggedTypes([.fileURL, .png, .tiff])

        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.documentView = collectionView
        context.coordinator.collectionView = collectionView
        context.coordinator.items = displayItems
        context.coordinator.itemPoses = itemPoses
        context.coordinator.lastItemIDs = displayItems.map(\.id)
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        context.coordinator.revealInFinderOnDoubleClick = revealInFinderOnDoubleClick
        context.coordinator.items = displayItems
        context.coordinator.itemPoses = itemPoses
        let currentIDs = displayItems.map(\.id)
        if currentIDs != context.coordinator.lastItemIDs {
            context.coordinator.lastItemIDs = currentIDs
            context.coordinator.collectionView?.reloadData()
        }
        context.coordinator.applyMotion()
    }

    @MainActor
    final class Coordinator: NSObject, NSCollectionViewDataSource, NSCollectionViewDelegate {
        let store: TrayStore
        var items: [TrayItem] = []
        var itemPoses: [UUID: MotionPose] = [:]
        let onExternalDragBegan: () -> Void
        let onExternalDragCompleted: (NSDragOperation) -> Void
        var revealInFinderOnDoubleClick: Bool
        weak var collectionView: NSCollectionView?
        var lastItemIDs: [UUID] = []
        private var promiseDelegates: [UUID: ImagePromiseDelegate] = [:]
        private let dragPreview = TrayDragPreviewSession()

        init(
            store: TrayStore,
            revealInFinderOnDoubleClick: Bool,
            onExternalDragBegan: @escaping () -> Void,
            onExternalDragCompleted: @escaping (NSDragOperation) -> Void
        ) {
            self.store = store
            self.revealInFinderOnDoubleClick = revealInFinderOnDoubleClick
            self.onExternalDragBegan = onExternalDragBegan
            self.onExternalDragCompleted = onExternalDragCompleted
        }

        func applyMotion() {
            guard let collectionView else { return }
            for path in collectionView.indexPathsForVisibleItems() {
                guard items.indices.contains(path.item),
                      let cell = collectionView.item(at: path) as? TrayCollectionViewItem else { continue }
                cell.applyMotion(itemPoses[items[path.item].id] ?? .identity)
            }
        }

        func openDoubleClickedItem(at indexPath: IndexPath) {
            let index = indexPath.item
            guard revealInFinderOnDoubleClick,
                  items.indices.contains(index),
                  let url = items[index].fileURL else { return }
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }

        func numberOfSections(in collectionView: NSCollectionView) -> Int { 1 }

        func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
            items.count
        }

        func collectionView(
            _ collectionView: NSCollectionView,
            itemForRepresentedObjectAt indexPath: IndexPath
        ) -> NSCollectionViewItem {
            guard let item = collectionView.makeItem(
                withIdentifier: TrayCollectionViewItem.identifier,
                for: indexPath
            ) as? TrayCollectionViewItem,
            items.indices.contains(indexPath.item) else {
                return NSCollectionViewItem()
            }

            let trayItem = items[indexPath.item]
            item.configure(with: trayItem)
            item.applyMotion(itemPoses[trayItem.id] ?? .identity)
            return item
        }

        func collectionView(
            _ collectionView: NSCollectionView,
            canDragItemsAt indexPaths: Set<IndexPath>,
            with event: NSEvent
        ) -> Bool {
            let draggedItems = indexPaths.compactMap { path in
                items.indices.contains(path.item) ? items[path.item] : nil
            }
            let operations = draggedItems.count == indexPaths.count
                ? TrayDragPolicy.operations(for: draggedItems) : []
            collectionView.setDraggingSourceOperationMask(operations, forLocal: false)
            collectionView.setDraggingSourceOperationMask(operations, forLocal: true)
            return !operations.isEmpty
        }

        func collectionView(
            _ collectionView: NSCollectionView,
            pasteboardWriterForItemAt indexPath: IndexPath
        ) -> NSPasteboardWriting? {
            guard items.indices.contains(indexPath.item) else { return nil }
            let item = items[indexPath.item]
            switch item.content {
            case let .file(url):
                return url as NSURL
            case let .image(data, _):
                let delegate = ImagePromiseDelegate(data: data, fileName: item.name)
                promiseDelegates[item.id] = delegate
                return NSFilePromiseProvider(fileType: UTType.png.identifier, delegate: delegate)
            }
        }

        func collectionView(
            _ collectionView: NSCollectionView,
            draggingSession session: NSDraggingSession,
            willBeginAt screenPoint: NSPoint,
            forItemsAt indexPaths: Set<IndexPath>
        ) {
            let draggedItems = indexPaths.sorted().compactMap { path in
                items.indices.contains(path.item) ? items[path.item] : nil
            }
            onExternalDragBegan()
            dragPreview.begin(session, items: draggedItems,
                              scale: collectionView.window?.backingScaleFactor ?? 2)
        }

        func collectionView(
            _ collectionView: NSCollectionView,
            draggingSession session: NSDraggingSession,
            endedAt screenPoint: NSPoint,
            dragOperation operation: NSDragOperation
        ) {
            dragPreview.end()
            promiseDelegates.removeAll()
            collectionView.setDraggingSourceOperationMask([], forLocal: false)
            collectionView.setDraggingSourceOperationMask([], forLocal: true)
            onExternalDragCompleted(operation)
        }

        func collectionView(
            _ collectionView: NSCollectionView,
            validateDrop draggingInfo: NSDraggingInfo,
            proposedIndexPath: AutoreleasingUnsafeMutablePointer<NSIndexPath>,
            dropOperation: UnsafeMutablePointer<NSCollectionView.DropOperation>
        ) -> NSDragOperation {
            guard !isInternalDrag(draggingInfo, in: collectionView) else {
                store.isDropTargeted = false
                return []
            }

            store.isDropTargeted = TrayPasteboardImporter.canImport(from: draggingInfo.draggingPasteboard)
            if store.isDropTargeted { draggingInfo.animatesToDestination = false }
            dropOperation.pointee = .on
            return store.isDropTargeted ? .copy : []
        }

        func collectionView(
            _ collectionView: NSCollectionView,
            acceptDrop draggingInfo: NSDraggingInfo,
            indexPath: IndexPath,
            dropOperation: NSCollectionView.DropOperation
        ) -> Bool {
            defer { store.isDropTargeted = false }
            guard !isInternalDrag(draggingInfo, in: collectionView) else { return false }
            return TrayPasteboardImporter.importDrop(draggingInfo, into: store, destination: collectionView)
        }

        private func isInternalDrag(_ draggingInfo: NSDraggingInfo, in collectionView: NSCollectionView) -> Bool {
            guard let sourceView = draggingInfo.draggingSource as? NSView else { return false }
            return sourceView.window === collectionView.window
        }
    }
}

final class DoubleClickCollectionView: NSCollectionView {
    var onDoubleClick: ((IndexPath) -> Void)?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        guard event.clickCount == 2 else { return }
        let point = convert(event.locationInWindow, from: nil)
        guard let indexPath = indexPathForItem(at: point) else { return }
        onDoubleClick?(indexPath)
    }
}

private final class TrayCollectionViewItem: NSCollectionViewItem {
    static let identifier = NSUserInterfaceItemIdentifier("TrayCollectionViewItem")

    private let previewBackground = FirstMouseView()
    private let iconView = FirstMouseImageView()
    private let nameField = FirstMouseTextField(labelWithString: "")
    private var representedID: UUID?
    private let motionBlur = CIFilter(name: "CIGaussianBlur")

    override func loadView() {
        view = HoverCellView()
        view.wantsLayer = true
        view.layer?.cornerRadius = 12

        previewBackground.translatesAutoresizingMaskIntoConstraints = false
        previewBackground.wantsLayer = true
        previewBackground.layer?.cornerRadius = 9
        previewBackground.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.055).cgColor

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.setContentHuggingPriority(.defaultHigh, for: .vertical)

        nameField.translatesAutoresizingMaskIntoConstraints = false
        nameField.alignment = .center
        nameField.font = .systemFont(ofSize: 12, weight: .medium)
        nameField.textColor = .labelColor
        nameField.lineBreakMode = .byTruncatingMiddle
        nameField.maximumNumberOfLines = 2

        view.addSubview(previewBackground)
        previewBackground.addSubview(iconView)
        view.addSubview(nameField)

        NSLayoutConstraint.activate([
            previewBackground.topAnchor.constraint(equalTo: view.topAnchor, constant: 7),
            previewBackground.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            previewBackground.widthAnchor.constraint(equalToConstant: 78),
            previewBackground.heightAnchor.constraint(equalToConstant: 66),

            iconView.topAnchor.constraint(equalTo: previewBackground.topAnchor, constant: 4),
            iconView.leadingAnchor.constraint(equalTo: previewBackground.leadingAnchor, constant: 4),
            iconView.trailingAnchor.constraint(equalTo: previewBackground.trailingAnchor, constant: -4),
            iconView.bottomAnchor.constraint(equalTo: previewBackground.bottomAnchor, constant: -4),

            nameField.topAnchor.constraint(equalTo: previewBackground.bottomAnchor, constant: 5),
            nameField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 6),
            nameField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -6),
            nameField.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -4)
        ])
    }

    override var isSelected: Bool {
        didSet { updateAppearance() }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        representedID = nil
        iconView.image = nil
    }

    func configure(with item: TrayItem) {
        representedID = item.id
        iconView.image = item.displayImage
        nameField.stringValue = item.name
        view.toolTip = item.accessibilityDescription
        view.setAccessibilityLabel(item.name)
        updateAppearance()

        guard case let .file(url) = item.content else { return }
        let requestedID = item.id
        let scale = view.window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        NativeThumbnailLoader.shared.loadThumbnail(
            for: url,
            size: NSSize(width: 70, height: 58),
            scale: scale
        ) { [weak self] thumbnail in
            guard self?.representedID == requestedID else { return }
            self?.iconView.image = thumbnail
        }
    }

    func applyMotion(_ pose: MotionPose) {
        guard let layer = view.layer else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.opacity = Float(pose.opacity)
        let offsetY = view.isFlipped ? pose.y : -pose.y
        var transform = CATransform3DMakeTranslation(view.bounds.midX, view.bounds.midY + offsetY, 0)
        transform = CATransform3DScale(transform, pose.scale, pose.scale, 1)
        transform = CATransform3DTranslate(transform, -view.bounds.midX, -view.bounds.midY, 0)
        layer.sublayerTransform = transform
        if pose.blur > 0, let motionBlur {
            motionBlur.setValue(pose.blur, forKey: kCIInputRadiusKey)
            layer.filters = [motionBlur]
        } else {
            layer.filters = nil
        }
        CATransaction.commit()
    }

    private func updateAppearance() {
        guard let cell = view as? HoverCellView else { return }
        cell.isItemSelected = isSelected
    }
}

@MainActor
final class NativeThumbnailLoader {
    static let shared = NativeThumbnailLoader()

    private let cache = NSCache<NSString, NSImage>()
    private var pending: [String: [(NSImage) -> Void]] = [:]
    private let pdfQueue = DispatchQueue(label: "MiniTray.pdf-previews", qos: .userInitiated)

    init() {
        cache.countLimit = 256
    }

    private func cacheKey(for url: URL, scale: CGFloat) -> String {
        "\(url.standardizedFileURL.path)|128|\(min(max(scale, 1), 4))"
    }

    func cachedThumbnail(for url: URL, scale: CGFloat) -> NSImage? {
        cache.object(forKey: cacheKey(for: url, scale: scale) as NSString)
    }

    func loadThumbnail(
        for url: URL,
        size: NSSize,
        scale: CGFloat,
        completion: @escaping (NSImage) -> Void
    ) {
        // Una miniatura común de suficiente resolución para pila, cuadrícula y arrastre.
        let density = min(max(scale.isFinite ? scale : 2, 1), 4)
        let key = cacheKey(for: url, scale: density)
        if let cachedImage = cache.object(forKey: key as NSString) {
            completion(cachedImage)
            return
        }

        if pending[key] != nil {
            pending[key]?.append(completion)
            return
        }
        pending[key] = [completion]
        let finish: (NSImage) -> Void = { [weak self] image in
            guard let self else { return }
            self.cache.setObject(image, forKey: key as NSString)
            let callbacks = self.pending.removeValue(forKey: key) ?? []
            callbacks.forEach { $0(image) }
        }

        let fallback = NSWorkspace.shared.icon(forFile: url.path)
        if UTType(filenameExtension: url.pathExtension)?.conforms(to: .pdf) == true {
            pdfQueue.async {
                let image = PDFPreviewRenderer.image(for: url, size: CGSize(width: 128, height: 128), scale: density)
                DispatchQueue.main.async { finish(image ?? fallback) }
            }
            return
        }

        if let directlyDecodableImage = NSImage(contentsOf: url) {
            if directlyDecodableImage.representations.contains(where: { $0 is NSPDFImageRep }) {
                pdfQueue.async {
                    let image = PDFPreviewRenderer.image(for: url, size: CGSize(width: 128, height: 128), scale: density)
                    DispatchQueue.main.async { finish(image ?? fallback) }
                }
            } else {
                finish(directlyDecodableImage)
            }
            return
        }

        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: NSSize(width: 128, height: 128),
            scale: density,
            representationTypes: .all
        )

        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, _ in
            DispatchQueue.main.async {
                let image = representation?.nsImage ?? fallback
                finish(image)
            }
        }
    }
}

final class FirstMouseView: NSView {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}

final class FirstMouseImageView: NSImageView {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}

final class FirstMouseTextField: NSTextField {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}

private final class HoverCellView: NSView {
    var isItemSelected = false {
        didSet { updateBackground() }
    }

    private var isHovered = false {
        didSet { updateBackground() }
    }
    private var trackingAreaReference: NSTrackingArea?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
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

    private func updateBackground() {
        if isItemSelected {
            layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.22).cgColor
            layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.65).cgColor
            layer?.borderWidth = 1
        } else if isHovered {
            layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.075).cgColor
            layer?.borderColor = NSColor.clear.cgColor
            layer?.borderWidth = 0
        } else {
            layer?.backgroundColor = NSColor.clear.cgColor
            layer?.borderColor = NSColor.clear.cgColor
            layer?.borderWidth = 0
        }
    }
}

final class ImagePromiseDelegate: NSObject, NSFilePromiseProviderDelegate {
    let data: Data
    let fileName: String

    init(data: Data, fileName: String) {
        self.data = data
        self.fileName = fileName
    }

    func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, fileNameForType fileType: String) -> String {
        fileName
    }

    func filePromiseProvider(
        _ filePromiseProvider: NSFilePromiseProvider,
        writePromiseTo url: URL,
        completionHandler: @escaping (Error?) -> Void
    ) {
        do {
            try data.write(to: url, options: .atomic)
            completionHandler(nil)
        } catch {
            completionHandler(error)
        }
    }
}
