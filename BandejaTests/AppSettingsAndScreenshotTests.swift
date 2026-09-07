import Carbon.HIToolbox
import XCTest
@testable import Bandeja

@MainActor
final class AppSettingsAndScreenshotTests: XCTestCase {
    func testDefaultsAreConservativeAndUseful() {
        let defaults = makeDefaults()
        let settings = AppSettings(defaults: defaults)

        XCTAssertEqual(settings.shakeSensitivity, .balanced)
        XCTAssertFalse(settings.shortcutEnabled)
        XCTAssertFalse(settings.screenshotDetectionEnabled)
        XCTAssertEqual(settings.screenshotTrayDuration, 3)
        XCTAssertTrue(settings.revealInFinderOnDoubleClick)
        XCTAssertEqual(settings.gestureMonitoringStatus, .checking)
    }

    func testPreferencesPersistWithoutTrayContents() {
        let defaults = makeDefaults()
        let first = AppSettings(defaults: defaults)
        first.shakeSensitivity = .high
        first.shortcutEnabled = true
        first.shortcutPreset = .commandShiftB
        first.screenshotDetectionEnabled = true
        first.screenshotTrayDuration = 4.5
        first.revealInFinderOnDoubleClick = false

        let restored = AppSettings(defaults: defaults)
        XCTAssertEqual(restored.shakeSensitivity, .high)
        XCTAssertTrue(restored.shortcutEnabled)
        XCTAssertEqual(restored.shortcutPreset, .commandShiftB)
        XCTAssertTrue(restored.screenshotDetectionEnabled)
        XCTAssertEqual(restored.screenshotTrayDuration, 4.5)
        XCTAssertFalse(restored.revealInFinderOnDoubleClick)
    }

    func testScreenshotFilterAcceptsOnlyFreshFileBackedCaptures() {
        let now = Date(timeIntervalSince1970: 1_000)
        let fileURL = URL(fileURLWithPath: "/tmp/fresh-capture.png")

        XCTAssertTrue(ScreenshotCandidateFilter.shouldHandle(
            isScreenCapture: true,
            url: fileURL,
            creationDate: now.addingTimeInterval(-2),
            now: now
        ))
        XCTAssertFalse(ScreenshotCandidateFilter.shouldHandle(
            isScreenCapture: false,
            url: fileURL,
            creationDate: now,
            now: now
        ))
        XCTAssertFalse(ScreenshotCandidateFilter.shouldHandle(
            isScreenCapture: true,
            url: fileURL,
            creationDate: now.addingTimeInterval(-31),
            now: now
        ))
        XCTAssertFalse(ScreenshotCandidateFilter.shouldHandle(
            isScreenCapture: true,
            url: URL(string: "https://example.com/capture.png"),
            creationDate: now,
            now: now
        ))
    }

    func testShortcutPresetsMapToDistinctKeyCombinations() {
        let definitions = GlobalShortcutPreset.allCases.map(GlobalShortcutMonitor.definition)
        let keys = definitions.map { "\($0.keyCode)-\($0.modifiers)" }

        XCTAssertEqual(Set(keys).count, GlobalShortcutPreset.allCases.count)
        XCTAssertTrue(definitions.allSatisfy { $0.modifiers != 0 })
    }

    func testGestureEventTapOnlyObservesRequiredMouseEvents() {
        let mask = GlobalDragMonitor.monitoredEventMask
        let contains: (CGEventType) -> Bool = { type in
            mask & (CGEventMask(1) << type.rawValue) != 0
        }

        XCTAssertTrue(contains(.leftMouseDown))
        XCTAssertTrue(contains(.leftMouseDragged))
        XCTAssertTrue(contains(.leftMouseUp))
        XCTAssertFalse(contains(.keyDown))
        XCTAssertFalse(contains(.keyUp))
        XCTAssertFalse(contains(.rightMouseDown))
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "AppSettingsAndScreenshotTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
