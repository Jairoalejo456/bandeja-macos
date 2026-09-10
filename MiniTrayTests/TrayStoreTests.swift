import AppKit
import XCTest
@testable import MiniTray

final class TrayStoreTests: XCTestCase {
    @MainActor
    func testAddingAndRemovingFileOnlyChangesReferences() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MiniTrayTests-\(UUID().uuidString)", isDirectory: true)
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
            .appendingPathComponent("MiniTrayTests-\(UUID().uuidString)", isDirectory: true)
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
        let missing = URL(fileURLWithPath: "/tmp/MiniTray-missing-\(UUID().uuidString)")

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
            .appendingPathComponent("MiniTrayTests-\(UUID().uuidString)", isDirectory: true)
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
            .appendingPathComponent("MiniTrayTests-\(UUID().uuidString)", isDirectory: true)
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
            .appendingPathComponent("MiniTrayTests-\(UUID().uuidString)", isDirectory: true)
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
            .appendingPathComponent("MiniTrayTests-\(UUID().uuidString)", isDirectory: true)
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
    func testSuccessfulCopyToAnImportingAppClearsReferencesButPreservesOriginal() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MiniTrayTests-\(UUID().uuidString)", isDirectory: true)
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
            .appendingPathComponent("MiniTrayTests-\(UUID().uuidString)", isDirectory: true)
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

    func testFileAndFolderDragAllowNativeMoveWithoutOfferingDelete() {
        for url in [URL(fileURLWithPath: "/tmp/documento.pdf"),
                    URL(fileURLWithPath: "/tmp/carpeta", isDirectory: true)] {
            let operations = TrayDragPolicy.operations(for: [TrayItem(url: url)])
            XCTAssertTrue(operations.contains(.move))
            XCTAssertTrue(operations.contains(.copy))
            XCTAssertFalse(operations.contains(.delete))
            XCTAssertFalse(operations.contains(.link))
        }
    }

    @MainActor
    func testMemoryOnlyImagesOfferCopyBecauseThereIsNoOriginalFile() {
        let image = TrayItem(imageData: Data(), image: NSImage(size: NSSize(width: 1, height: 1)), name: "imagen.png")
        XCTAssertEqual(TrayDragPolicy.operations(for: [image]), .copy)
        XCTAssertEqual(TrayDragPolicy.operations(for: []), [])
    }

    @MainActor
    func testMixedStackStillAllowsMovingItsOriginalFiles() {
        let image = TrayItem(imageData: Data(), image: NSImage(size: NSSize(width: 1, height: 1)), name: "imagen.png")
        let file = TrayItem(url: URL(fileURLWithPath: "/tmp/documento.pdf"))
        XCTAssertEqual(TrayDragPolicy.operations(for: [image, file]), [.copy, .move])
    }

    @MainActor
    func testExpandedSelectionUsesOnlyTheItemsActuallyDragged() throws {
        let store = TrayStore()
        let coordinator = TrayCollectionView.Coordinator(
            store: store, revealInFinderOnDoubleClick: true,
            onExternalDragBegan: {}, onExternalDragCompleted: { _ in }
        )
        coordinator.items = [
            TrayItem(url: URL(fileURLWithPath: "/tmp/documento.pdf")),
            TrayItem(imageData: Data(), image: NSImage(size: NSSize(width: 1, height: 1)), name: "imagen.png")
        ]
        let collection = RecordingDragCollectionView()
        let event = try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseDragged, location: .zero,
            modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil,
            eventNumber: 0, clickCount: 1, pressure: 1))
        let file = IndexPath(item: 0, section: 0)
        let image = IndexPath(item: 1, section: 0)
        XCTAssertTrue(coordinator.collectionView(collection, canDragItemsAt: [file], with: event))
        XCTAssertEqual(collection.externalOperations, [.copy, .move])
        XCTAssertEqual(collection.localOperations, [.copy, .move])
        XCTAssertTrue(coordinator.collectionView(collection, canDragItemsAt: [image], with: event))
        XCTAssertEqual(collection.externalOperations, .copy)
        XCTAssertTrue(coordinator.collectionView(collection, canDragItemsAt: [file, image], with: event))
        XCTAssertEqual(collection.externalOperations, [.copy, .move])
        XCTAssertFalse(coordinator.collectionView(collection, canDragItemsAt: [IndexPath(item: 20, section: 0)], with: event))
        XCTAssertEqual(collection.externalOperations, [])
    }

    @MainActor
    func testMoveCompletionOnlyForgetsReferencesAndNeverDeletesAReplacementAtSource() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MiniTrayTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("original.pdf")
        let destination = directory.appendingPathComponent("destino.pdf")
        let bytes = Data("contenido original".utf8)
        try bytes.write(to: source)
        let store = TrayStore()
        store.addFileURLs([source])
        let controller = TrayPanelController(store: store)
        controller.beginExternalDrag()

        // Simula una operación de destino; la prueba no afirma ser Finder real.
        try FileManager.default.moveItem(at: source, to: destination)
        let replacement = Data("otro archivo que apareció en la misma ruta".utf8)
        try replacement.write(to: source)
        controller.completeExternalDrag(.move)

        XCTAssertTrue(store.items.isEmpty)
        XCTAssertFalse(store.isDraggingOut)
        XCTAssertEqual(try Data(contentsOf: destination), bytes)
        XCTAssertEqual(try Data(contentsOf: source), replacement)
    }

    @MainActor
    func testCancelThenCloseNeverMovesAnOriginal() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MiniTrayTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("cancelado.pdf")
        let bytes = Data("conservar exactamente".utf8)
        try bytes.write(to: source)
        let store = TrayStore()
        store.addFileURLs([source])
        let controller = TrayPanelController(store: store)
        controller.beginExternalDrag()
        controller.completeExternalDrag([])
        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(try Data(contentsOf: source), bytes)
        controller.closeAndClear()
        XCTAssertTrue(store.items.isEmpty)
        XCTAssertEqual(try Data(contentsOf: source), bytes)
    }
}

private final class RecordingDragCollectionView: NSCollectionView {
    private(set) var externalOperations: NSDragOperation = []
    private(set) var localOperations: NSDragOperation = []

    override func setDraggingSourceOperationMask(_ dragOperationMask: NSDragOperation, forLocal local: Bool) {
        if local { localOperations = dragOperationMask } else { externalOperations = dragOperationMask }
        super.setDraggingSourceOperationMask(dragOperationMask, forLocal: local)
    }
}
