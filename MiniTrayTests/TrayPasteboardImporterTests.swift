import AppKit
import XCTest
@testable import MiniTray

final class TrayPasteboardImporterTests: XCTestCase {
    @MainActor
    func testImportsMultipleFileURLsFromPasteboardWithoutChangingFiles() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MiniTrayPasteboard-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let first = directory.appendingPathComponent("primero.txt")
        let second = directory.appendingPathComponent("segundo.txt")
        try Data("primero".utf8).write(to: first)
        try Data("segundo".utf8).write(to: second)

        let pasteboard = NSPasteboard(name: NSPasteboard.Name("MiniTrayTests-\(UUID().uuidString)"))
        pasteboard.clearContents()
        XCTAssertTrue(pasteboard.writeObjects([first as NSURL, second as NSURL]))

        let store = TrayStore()
        XCTAssertTrue(TrayPasteboardImporter.canImport(from: pasteboard))
        XCTAssertEqual(TrayPasteboardImporter.importItems(from: pasteboard, into: store), 2)
        XCTAssertEqual(store.items.count, 2)
        XCTAssertEqual(try String(contentsOf: first, encoding: .utf8), "primero")
        XCTAssertEqual(try String(contentsOf: second, encoding: .utf8), "segundo")
    }

    @MainActor
    func testImportsRawImageAsMemoryOnlyItem() throws {
        let sourceImage = try XCTUnwrap(NSImage(systemSymbolName: "photo.fill", accessibilityDescription: nil))
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("MiniTrayTests-\(UUID().uuidString)"))
        pasteboard.clearContents()
        XCTAssertTrue(pasteboard.writeObjects([sourceImage]))

        let store = TrayStore()
        XCTAssertTrue(TrayPasteboardImporter.canImport(from: pasteboard))
        XCTAssertEqual(TrayPasteboardImporter.importItems(from: pasteboard, into: store), 1)
        XCTAssertEqual(store.items.count, 1)
        XCTAssertNil(store.items.first?.fileURL)
    }

    func testMemoryImagePromiseWritesTheOriginalData() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MiniTrayPromise-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let expectedData = Data("temporary-image-data".utf8)
        let destination = directory.appendingPathComponent("Imagen.png")
        let delegate = ImagePromiseDelegate(data: expectedData, fileName: destination.lastPathComponent)
        let provider = NSFilePromiseProvider(fileType: "public.png", delegate: delegate)
        let completed = expectation(description: "La promesa de imagen termina")
        var writeError: Error?

        delegate.filePromiseProvider(provider, writePromiseTo: destination) { error in
            writeError = error
            completed.fulfill()
        }

        wait(for: [completed], timeout: 1)
        XCTAssertNil(writeError)
        XCTAssertEqual(try Data(contentsOf: destination), expectedData)
    }
}
