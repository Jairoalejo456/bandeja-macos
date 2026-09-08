import AppKit
import XCTest
@testable import Bandeja

final class TrayStoreTests: XCTestCase {
    @MainActor
    func testAddingAndRemovingFileOnlyChangesReferences() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BandejaTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let original = directory.appendingPathComponent("original.txt")
        let originalData = Data("contenido intacto".utf8)
        try originalData.write(to: original)

        let store = TrayStore()
        XCTAssertEqual(store.addFileURLs([original]), 1)
        XCTAssertEqual(store.items.count, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: original.path))
        XCTAssertEqual(try Data(contentsOf: original), originalData)

        store.remove(id: try XCTUnwrap(store.items.first?.id))
        XCTAssertTrue(store.items.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: original.path))
        XCTAssertEqual(try Data(contentsOf: original), originalData)
    }

    @MainActor
    func testMultipleFilesFoldersAndDuplicates() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BandejaTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let first = directory.appendingPathComponent("uno.txt")
        let second = directory.appendingPathComponent("dos.txt")
        let folder = directory.appendingPathComponent("Carpeta", isDirectory: true)
        try Data("1".utf8).write(to: first)
        try Data("2".utf8).write(to: second)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let store = TrayStore()
        XCTAssertEqual(store.addFileURLs([first, second, folder, first]), 3)
        XCTAssertEqual(store.items.count, 3)
        XCTAssertEqual(store.addFileURLs([second]), 0)

        store.clear()
        XCTAssertTrue(FileManager.default.fileExists(atPath: first.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: second.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.path))
    }

    @MainActor
    func testMissingAndNonFileURLsAreRejected() {
        let store = TrayStore()
        let missing = URL(fileURLWithPath: "/tmp/Bandeja-missing-\(UUID().uuidString)")

        XCTAssertEqual(store.addFileURLs([missing, URL(string: "https://example.com")!]), 0)
        XCTAssertTrue(store.items.isEmpty)
    }

    @MainActor
    func testImageNamesRemainUniqueInMemory() {
        let store = TrayStore()
        let image = NSImage(size: NSSize(width: 4, height: 4))
        let data = Data([0, 1, 2])

        let first = store.addImage(data: data, image: image, suggestedName: "Imagen.png")
        let second = store.addImage(data: data, image: image, suggestedName: "Imagen.png")

        XCTAssertEqual(first.name, "Imagen.png")
        XCTAssertEqual(second.name, "Imagen 2.png")
    }

    @MainActor
    func testEmptyCallbackRunsWhenLastReferenceIsRemoved() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BandejaTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let file = directory.appendingPathComponent("item.txt")
        try Data().write(to: file)
        let store = TrayStore()
        var callbackCount = 0
        store.onBecameEmpty = { callbackCount += 1 }
        store.addFileURLs([file])

        store.remove(id: try XCTUnwrap(store.items.first?.id))
        XCTAssertEqual(callbackCount, 1)
    }

    @MainActor
    func testClosingPanelClearsReferencesButPreservesOriginal() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BandejaTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let file = directory.appendingPathComponent("conservar.txt")
        let originalData = Data("no borrar".utf8)
        try originalData.write(to: file)

        let store = TrayStore()
        store.addFileURLs([file])
        let panelController = TrayPanelController(store: store)

        panelController.closeAndClear()

        XCTAssertTrue(store.items.isEmpty)
        XCTAssertEqual(try Data(contentsOf: file), originalData)
    }

    @MainActor
    func testExpandedStateCanCollapseAndResetsWhenCleared() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BandejaTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let file = directory.appendingPathComponent("vista.txt")
        try Data().write(to: file)
        let store = TrayStore()

        store.expand()
        XCTAssertFalse(store.isExpanded, "Una bandeja vacía no debe expandirse")

        store.addFileURLs([file])
        store.expand()
        XCTAssertTrue(store.isExpanded)
        store.collapse()
        XCTAssertFalse(store.isExpanded)

        store.expand()
        store.clear()
        XCTAssertFalse(store.isExpanded)
    }

    @MainActor
    func testCancelledExternalDragKeepsReferences() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BandejaTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let file = directory.appendingPathComponent("cancelado.txt")
        try Data("conservar".utf8).write(to: file)
        let store = TrayStore()
        store.addFileURLs([file])
        let panelController = TrayPanelController(store: store)

        panelController.completeExternalDrag([])

        XCTAssertEqual(store.items.count, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
    }

    @MainActor
    func testSuccessfulExternalDragClearsReferencesButPreservesOriginal() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BandejaTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let file = directory.appendingPathComponent("entregado.txt")
        let originalData = Data("permanece".utf8)
        try originalData.write(to: file)
        let store = TrayStore()
        store.addFileURLs([file])
        let panelController = TrayPanelController(store: store)

        panelController.completeExternalDrag(.copy)

        XCTAssertTrue(store.items.isEmpty)
        XCTAssertEqual(try Data(contentsOf: file), originalData)
    }

    @MainActor
    func testExternalDragStateRestoresAfterCancellationAndClear() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BandejaTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let file = directory.appendingPathComponent("arrastre.txt")
        try Data().write(to: file)
        let store = TrayStore()
        store.addFileURLs([file])

        store.beginExternalDrag()
        XCTAssertTrue(store.isDraggingOut)

        store.endExternalDrag()
        XCTAssertFalse(store.isDraggingOut)
        XCTAssertEqual(store.items.count, 1)

        store.beginExternalDrag()
        store.clear()
        XCTAssertFalse(store.isDraggingOut)
    }
}
