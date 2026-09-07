import Foundation
import ServiceManagement

enum LaunchAtLoginStatus: Equatable {
    case disabled
    case enabled
    case requiresApproval
    case unavailable
}

protocol LaunchAtLoginServicing: AnyObject {
    var status: SMAppService.Status { get }
    func register() throws
    func unregister() throws
}

extension SMAppService: LaunchAtLoginServicing {}

@MainActor
final class LaunchAtLoginController: ObservableObject {
    @Published private(set) var status: LaunchAtLoginStatus = .disabled
    @Published private(set) var errorMessage: String?

    private let service: any LaunchAtLoginServicing

    var isEnabled: Bool {
        status == .enabled || status == .requiresApproval
    }

    init(service: any LaunchAtLoginServicing = SMAppService.mainApp) {
        self.service = service
        refresh()
    }

    func setEnabled(_ shouldEnable: Bool) {
        errorMessage = nil

        do {
            if shouldEnable {
                if service.status != .enabled, service.status != .requiresApproval {
                    try service.register()
                }
            } else if service.status != .notRegistered {
                try service.unregister()
            }
            refresh()
        } catch {
            refresh()
            errorMessage = shouldEnable
                ? "No se pudo activar el inicio automático."
                : "No se pudo desactivar el inicio automático."
        }
    }

    func refresh() {
        switch service.status {
        case .notRegistered, .notFound:
            status = .disabled
        case .enabled:
            status = .enabled
        case .requiresApproval:
            status = .requiresApproval
        @unknown default:
            status = .unavailable
        }
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}

enum GlobalShortcutPreset: String, CaseIterable, Identifiable {
    case controlOptionSpace
    case optionCommandSpace
    case optionShiftSpace
    case commandShiftB

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .controlOptionSpace: return "⌃⌥ Espacio"
        case .optionCommandSpace: return "⌥⌘ Espacio"
        case .optionShiftSpace: return "⌥⇧ Espacio"
        case .commandShiftB: return "⇧⌘ B"
        }
    }
}

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private enum Key {
        static let shakeSensitivity = "shakeSensitivity"
        static let shortcutEnabled = "shortcutEnabled"
        static let shortcutPreset = "shortcutPreset"
        static let screenshotDetectionEnabled = "screenshotDetectionEnabled"
        static let screenshotTrayDuration = "screenshotTrayDuration"
        static let revealInFinderOnDoubleClick = "revealInFinderOnDoubleClick"
    }

    private let defaults: UserDefaults

    @Published var shakeSensitivity: GlobalDragMonitor.Sensitivity {
        didSet { defaults.set(shakeSensitivity.rawValue, forKey: Key.shakeSensitivity) }
    }

    @Published var shortcutEnabled: Bool {
        didSet { defaults.set(shortcutEnabled, forKey: Key.shortcutEnabled) }
    }

    @Published var shortcutPreset: GlobalShortcutPreset {
        didSet { defaults.set(shortcutPreset.rawValue, forKey: Key.shortcutPreset) }
    }

    @Published var screenshotDetectionEnabled: Bool {
        didSet { defaults.set(screenshotDetectionEnabled, forKey: Key.screenshotDetectionEnabled) }
    }

    @Published var screenshotTrayDuration: Double {
        didSet { defaults.set(screenshotTrayDuration, forKey: Key.screenshotTrayDuration) }
    }

    @Published var revealInFinderOnDoubleClick: Bool {
        didSet { defaults.set(revealInFinderOnDoubleClick, forKey: Key.revealInFinderOnDoubleClick) }
    }

    @Published private(set) var shortcutStatus: String?
    @Published private(set) var screenshotStatus: String?
    @Published private(set) var gestureMonitoringStatus: GestureMonitoringStatus = .checking

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let storedSensitivity = defaults.string(forKey: Key.shakeSensitivity)
        shakeSensitivity = GlobalDragMonitor.Sensitivity(rawValue: storedSensitivity ?? "") ?? .balanced

        shortcutEnabled = defaults.object(forKey: Key.shortcutEnabled) as? Bool ?? false
        shortcutPreset = GlobalShortcutPreset(rawValue: defaults.string(forKey: Key.shortcutPreset) ?? "")
            ?? .controlOptionSpace
        screenshotDetectionEnabled = defaults.object(forKey: Key.screenshotDetectionEnabled) as? Bool ?? false

        let storedDuration = defaults.double(forKey: Key.screenshotTrayDuration)
        screenshotTrayDuration = storedDuration > 0 ? min(max(storedDuration, 1), 10) : 3

        revealInFinderOnDoubleClick = defaults.object(forKey: Key.revealInFinderOnDoubleClick) as? Bool ?? true
    }

    func setShortcutStatus(_ status: String?) {
        shortcutStatus = status
    }

    func setScreenshotStatus(_ status: String?) {
        screenshotStatus = status
    }

    func setGestureMonitoringStatus(_ status: GestureMonitoringStatus) {
        gestureMonitoringStatus = status
    }
}
