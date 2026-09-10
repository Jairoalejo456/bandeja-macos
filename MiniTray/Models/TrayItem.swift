import AppKit
import Foundation
import UniformTypeIdentifiers

struct TrayItem: Identifiable {
    enum Content {
        case file(URL)
        case image(data: Data, image: NSImage)
    }

    let id: UUID
    let name: String
    let content: Content
    // Metadata is sampled on collection, never from the animation render loop.
    let byteCount: Int64
    let isImage: Bool

    init(id: UUID = UUID(), url: URL) {
        self.id = id
        self.name = url.lastPathComponent
        self.content = .file(url.standardizedFileURL)
        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .totalFileAllocatedSizeKey])
        self.byteCount = Int64(values?.totalFileAllocatedSize ?? values?.fileSize ?? 0)
        self.isImage = UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) ?? false
    }

    init(id: UUID = UUID(), imageData: Data, image: NSImage, name: String) {
        self.id = id
        self.name = name
        self.content = .image(data: imageData, image: image)
        self.byteCount = Int64(imageData.count)
        self.isImage = true
    }

    var fileURL: URL? {
        guard case let .file(url) = content else { return nil }
        return url
    }

    var displayImage: NSImage {
        switch content {
        case let .file(url):
            return NSWorkspace.shared.icon(forFile: url.path)
        case let .image(_, image):
            return image
        }
    }

    var accessibilityDescription: String {
        switch content {
        case let .file(url):
            return "\(name), \(url.path)"
        case .image:
            return "\(name), imagen en memoria"
        }
    }
}

/// Operaciones de salida; recoger elementos sigue siendo no destructivo.
enum TrayDragPolicy {
    static func operations(for items: [TrayItem]) -> NSDragOperation {
        guard !items.isEmpty else { return [] }
        // Finder puede trasladar las URLs originales. Copy conserva la compatibilidad
        // con destinos que importan/adjuntan datos y con la tecla Opción de macOS.
        // Una imagen solo en memoria no tiene un archivo de origen que trasladar.
        return items.contains(where: { $0.fileURL != nil }) ? [.move, .copy] : .copy
    }
}
