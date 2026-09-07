import AppKit
import Foundation

struct TrayItem: Identifiable {
    enum Content {
        case file(URL)
        case image(data: Data, image: NSImage)
    }

    let id: UUID
    let name: String
    let content: Content

    init(id: UUID = UUID(), url: URL) {
        self.id = id
        self.name = url.lastPathComponent
        self.content = .file(url.standardizedFileURL)
    }

    init(id: UUID = UUID(), imageData: Data, image: NSImage, name: String) {
        self.id = id
        self.name = name
        self.content = .image(data: imageData, image: image)
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
