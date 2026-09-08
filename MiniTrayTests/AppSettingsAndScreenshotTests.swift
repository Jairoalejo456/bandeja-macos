import Carbon.HIToolbox
import ServiceManagement
import XCTest
@testable import MiniTray

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

    func testLaunchAtLoginControllerRegistersAndUnregistersMainApp() {
        let service = FakeLaunchAtLoginService(status: .notRegistered)
        let controller = LaunchAtLoginController(service: service)

        XCTAssertEqual(controller.status, .disabled)
        XCTAssertFalse(controller.isEnabled)

        controller.setEnabled(true)
        XCTAssertEqual(service.registerCallCount, 1)
        XCTAssertEqual(controller.status, .enabled)
        XCTAssertTrue(controller.isEnabled)

        controller.setEnabled(false)
        XCTAssertEqual(service.unregisterCallCount, 1)
        XCTAssertEqual(controller.status, .disabled)
        XCTAssertFalse(controller.isEnabled)
    }

    func testLaunchAtLoginControllerReflectsApprovalAndNeverRegisteredStates() {
        let service = FakeLaunchAtLoginService(status: .requiresApproval)
        let controller = LaunchAtLoginController(service: service)

        XCTAssertEqual(controller.status, .requiresApproval)
        XCTAssertTrue(controller.isEnabled)

        service.status = .notFound
        controller.refresh()
        XCTAssertEqual(controller.status, .disabled)
        XCTAssertFalse(controller.isEnabled)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "AppSettingsAndScreenshotTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}

private final class FakeLaunchAtLoginService: LaunchAtLoginServicing {
    var status: SMAppService.Status
    private(set) var registerCallCount = 0
    private(set) var unregisterCallCount = 0

    init(status: SMAppService.Status) {
        self.status = status
    }

    func register() throws {
        registerCallCount += 1
        status = .enabled
    }

    func unregister() throws {
        unregisterCallCount += 1
        status = .notRegistered
    }
}
