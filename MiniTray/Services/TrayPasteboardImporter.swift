import AppKit

struct TrayIncomingDrop {
    let screenPoint: CGPoint
    let folderImage: NSImage?
}

@MainActor
enum TrayPasteboardImporter {
    /// Acceptance never waits for motion and never changes the source files.
    static func importDrop(_ sender: NSDraggingInfo, into store: TrayStore, destination: NSView) -> Bool {
        let before = Set(store.items.map(\.id))
        guard importItems(from: sender.draggingPasteboard, into: store) > 0 else { return false }
        let added = store.items.filter { !before.contains($0.id) }
        let folder = added.first { item in
            guard let url = item.fileURL else { return false }
            return (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        }
        let point = destination.window?.convertPoint(toScreen: sender.draggingLocation) ?? NSEvent.mouseLocation
        store.onAcceptedDrop?(TrayIncomingDrop(screenPoint: point, folderImage: folder?.displayImage))
        return true
    }

    static func canImport(from pasteboard: NSPasteboard) -> Bool {
        pasteboard.canReadObject(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) || NSImage.canInit(with: pasteboard)
    }

    @discardableResult
    static func importItems(from pasteboard: NSPasteboard, into store: TrayStore) -> Int {
        if let objects = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [NSURL], !objects.isEmpty {
            return store.addFileURLs(objects.map { $0 as URL })
        }

        guard let image = NSImage(pasteboard: pasteboard),
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            return 0
        }
        store.addImage(data: png, image: image)
        return 1
    }
}
