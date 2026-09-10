import AppKit
import Foundation

@MainActor
final class TrayStore: ObservableObject {
    @Published private(set) var items: [TrayItem] = []
    @Published var isDropTargeted = false
    @Published var statusMessage: String?
    @Published private(set) var isExpanded = false
    @Published private(set) var isDraggingOut = false

    var onBecameEmpty: (() -> Void)?
    var onAcceptedDrop: ((TrayIncomingDrop) -> Void)?

    @discardableResult
    func addFileURLs(_ urls: [URL]) -> Int {
        let existingPaths = Set(items.compactMap(\.fileURL).map(canonicalPath))
        var paths = existingPaths
        var added = 0
        var additions: [TrayItem] = []

        for url in urls where url.isFileURL {
            let normalizedURL = url.standardizedFileURL
            let path = canonicalPath(normalizedURL)
            guard !paths.contains(path) else { continue }
            guard FileManager.default.fileExists(atPath: normalizedURL.path) else { continue }

            additions.append(TrayItem(url: normalizedURL))
            paths.insert(path)
            added += 1
        }

        if added > 0 {
            items.append(contentsOf: additions)
            statusMessage = nil
        }
        return added
    }

    @discardableResult
    func addImage(data: Data, image: NSImage, suggestedName: String? = nil) -> TrayItem {
        let name = uniqueImageName(suggestedName)
        let item = TrayItem(imageData: data, image: image, name: name)
        items.append(item)
        statusMessage = nil
        return item
    }

    func remove(id: UUID) {
        items.removeAll { $0.id == id }
        notifyIfEmpty()
    }

    func remove(ids: Set<UUID>) {
        guard items.contains(where: { ids.contains($0.id) }) else { return }
        items.removeAll { ids.contains($0.id) }
        notifyIfEmpty()
    }

    func remove(at indexes: IndexSet) {
        for index in indexes.sorted(by: >) where items.indices.contains(index) {
            items.remove(at: index)
        }
        notifyIfEmpty()
    }

    func clear() {
        items.removeAll()
        isExpanded = false
        isDraggingOut = false
        statusMessage = nil
        notifyIfEmpty()
    }

    func expand() {
        guard !items.isEmpty else { return }
        isExpanded = true
    }

    func collapse() {
        isExpanded = false
    }

    func beginExternalDrag() {
        guard !items.isEmpty else { return }
        isDraggingOut = true
    }

    func endExternalDrag() {
        isDraggingOut = false
    }

    func item(withID id: UUID) -> TrayItem? {
        items.first { $0.id == id }
    }

    private func canonicalPath(_ url: URL) -> String {
        url.resolvingSymlinksInPath().standardizedFileURL.path
    }

    private func uniqueImageName(_ suggestedName: String?) -> String {
        let base = (suggestedName?.isEmpty == false ? suggestedName! : "Imagen.png")
        let ext = (base as NSString).pathExtension.isEmpty ? "png" : (base as NSString).pathExtension
        let stem = (base as NSString).deletingPathExtension
        let currentNames = Set(items.map(\.name))
        guard currentNames.contains(base) else { return base }

        var index = 2
        while currentNames.contains("\(stem) \(index).\(ext)") {
            index += 1
        }
        return "\(stem) \(index).\(ext)"
    }

    private func notifyIfEmpty() {
        if items.isEmpty {
            isExpanded = false
            isDraggingOut = false
            onBecameEmpty?()
        }
    }
}
