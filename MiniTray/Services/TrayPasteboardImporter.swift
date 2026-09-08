import AppKit

@MainActor
enum TrayPasteboardImporter {
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
