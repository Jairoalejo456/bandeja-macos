import AppKit
import QuickLookThumbnailing
import SwiftUI
import UniformTypeIdentifiers

struct TrayCollectionView: NSViewRepresentable {
    @ObservedObject var store: TrayStore
    let revealInFinderOnDoubleClick: Bool
    let onExternalDragCompleted: (NSDragOperation) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            store: store,
            revealInFinderOnDoubleClick: revealInFinderOnDoubleClick,
            onExternalDragCompleted: onExternalDragCompleted
        )
    }

    func makeNSView(context: Context) -> NSScrollView {
        let layout = NSCollectionViewFlowLayout()
        layout.itemSize = NSSize(width: 112, height: 108)
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
        collectionView.setDraggingSourceOperationMask(.copy, forLocal: false)
        collectionView.setDraggingSourceOperationMask(.copy, forLocal: true)
        collectionView.registerForDraggedTypes([.fileURL, .png, .tiff])

        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.documentView = collectionView
        context.coordinator.collectionView = collectionView
        context.coordinator.lastItemIDs = store.items.map(\.id)
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        context.coordinator.revealInFinderOnDoubleClick = revealInFinderOnDoubleClick
        let currentIDs = store.items.map(\.id)
        if currentIDs != context.coordinator.lastItemIDs {
            context.coordinator.lastItemIDs = currentIDs
            context.coordinator.collectionView?.reloadData()
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSCollectionViewDataSource, NSCollectionViewDelegate {
        let store: TrayStore
        let onExternalDragCompleted: (NSDragOperation) -> Void
        var revealInFinderOnDoubleClick: Bool
        weak var collectionView: NSCollectionView?
        var lastItemIDs: [UUID] = []
        private var promiseDelegates: [UUID: ImagePromiseDelegate] = [:]

        init(
            store: TrayStore,
            revealInFinderOnDoubleClick: Bool,
            onExternalDragCompleted: @escaping (NSDragOperation) -> Void
        ) {
            self.store = store
            self.revealInFinderOnDoubleClick = revealInFinderOnDoubleClick
            self.onExternalDragCompleted = onExternalDragCompleted
        }

        func openDoubleClickedItem(at indexPath: IndexPath) {
            let index = indexPath.item
            guard revealInFinderOnDoubleClick,
                  store.items.indices.contains(index),
                  let url = store.items[index].fileURL else { return }
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }

        func numberOfSections(in collectionView: NSCollectionView) -> Int { 1 }

        func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
            store.items.count
        }

        func collectionView(
            _ collectionView: NSCollectionView,
            itemForRepresentedObjectAt indexPath: IndexPath
        ) -> NSCollectionViewItem {
            guard let item = collectionView.makeItem(
                withIdentifier: TrayCollectionViewItem.identifier,
                for: indexPath
            ) as? TrayCollectionViewItem,
            store.items.indices.contains(indexPath.item) else {
                return NSCollectionViewItem()
            }

            let trayItem = store.items[indexPath.item]
            item.configure(with: trayItem)
            return item
        }

        func collectionView(
            _ collectionView: NSCollectionView,
            pasteboardWriterForItemAt indexPath: IndexPath
        ) -> NSPasteboardWriting? {
            guard store.items.indices.contains(indexPath.item) else { return nil }
            let item = store.items[indexPath.item]
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
            endedAt screenPoint: NSPoint,
            dragOperation operation: NSDragOperation
        ) {
            promiseDelegates.removeAll()
            if !operation.isEmpty {
                onExternalDragCompleted(operation)
            }
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
            return TrayPasteboardImporter.importItems(from: draggingInfo.draggingPasteboard, into: store) > 0
        }

        private func isInternalDrag(_ draggingInfo: NSDraggingInfo, in collectionView: NSCollectionView) -> Bool {
            guard let sourceView = draggingInfo.draggingSource as? NSView else { return false }
            return sourceView.window === collectionView.window
        }
    }
}

private final class DoubleClickCollectionView: NSCollectionView {
    var onDoubleClick: ((IndexPath) -> Void)?

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

    private let previewBackground = NSView()
    private let iconView = NSImageView()
    private let nameField = NSTextField(labelWithString: "")
    private var representedID: UUID?

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

    private func updateAppearance() {
        guard let cell = view as? HoverCellView else { return }
        cell.isItemSelected = isSelected
    }
}

@MainActor
final class NativeThumbnailLoader {
    static let shared = NativeThumbnailLoader()

    private let cache = NSCache<NSString, NSImage>()

    func loadThumbnail(
        for url: URL,
        size: NSSize,
        scale: CGFloat,
        completion: @escaping (NSImage) -> Void
    ) {
        let key = "\(url.standardizedFileURL.path)|\(Int(size.width))x\(Int(size.height))|\(scale)"
        if let cachedImage = cache.object(forKey: key as NSString) {
            completion(cachedImage)
            return
        }

        if let directlyDecodableImage = NSImage(contentsOf: url) {
            cache.setObject(directlyDecodableImage, forKey: key as NSString)
            completion(directlyDecodableImage)
            return
        }

        let fallback = NSWorkspace.shared.icon(forFile: url.path)
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: size,
            scale: scale,
            representationTypes: .all
        )

        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { [weak self] representation, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                let image = representation?.nsImage ?? fallback
                self.cache.setObject(image, forKey: key as NSString)
                completion(image)
            }
        }
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
