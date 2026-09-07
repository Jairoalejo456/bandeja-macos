import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let store = TrayStore()
    private let settings = AppSettings.shared
    private var panelController: TrayPanelController!
    private var dragMonitor: GlobalDragMonitor!
    private var shortcutMonitor: GlobalShortcutMonitor!
    private var screenshotMonitor: ScreenshotMonitor!
    private var launchAtLoginController: LaunchAtLoginController!
    private var settingsWindowController: SettingsWindowController!
    private var subscriptions: Set<AnyCancellable> = []
    private var statusItem: NSStatusItem!
    private weak var sensitivityMenu: NSMenu?
    private weak var gestureStatusMenuItem: NSMenuItem?
    private weak var requestPermissionMenuItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--show-settings") {
            NSApp.setActivationPolicy(.regular)
        }
#endif

        panelController = TrayPanelController(store: store, settings: settings)
        dragMonitor = GlobalDragMonitor(
            sensitivity: settings.shakeSensitivity,
            onShake: { [weak self] cursor in
                self?.panelController.showNearCursor(cursor)
            },
            onDragEnded: { [weak self] in
                self?.panelController.dragDidEnd()
            },
            onStatusChange: { [weak self] status in
                self?.handleGestureMonitoringStatus(status)
            }
        )
        launchAtLoginController = LaunchAtLoginController()
        settingsWindowController = SettingsWindowController(
            settings: settings,
            launchAtLogin: launchAtLoginController,
            onRequestInputMonitoring: { [weak self] in
                self?.requestInputMonitoringPermission()
            }
        )

        shortcutMonitor = GlobalShortcutMonitor { [weak self] in
            self?.panelController.showNearCursor()
        }
        screenshotMonitor = ScreenshotMonitor()
        screenshotMonitor.onScreenshot = { [weak self] _ in
            guard let self else { return }
            self.panelController.showNearCursor(
                emptyDismissAfter: self.settings.screenshotTrayDuration
            )
        }
        screenshotMonitor.onStatusChange = { [weak self] status in
            self?.handleScreenshotStatus(status)
        }

        observeSettings()
        configureStatusItem()
        let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        dragMonitor.start(requestPermission: !isRunningTests)

#if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        let debugURLs = arguments.enumerated().compactMap { index, argument -> URL? in
            guard argument == "--qa-add", arguments.indices.contains(index + 1) else { return nil }
            return URL(fileURLWithPath: arguments[index + 1])
        }
        if !debugURLs.isEmpty {
            store.addFileURLs(debugURLs)
        }
        if arguments.contains("--show-tray") {
            DispatchQueue.main.async { [weak self] in
                self?.panelController.showNearCursor()
            }
        }
        if arguments.contains("--show-settings") {
            DispatchQueue.main.async { [weak self] in
                self?.settingsWindowController.show()
            }
        }
#endif
    }

    func applicationWillTerminate(_ notification: Notification) {
        dragMonitor.stop()
        shortcutMonitor.unregister()
        screenshotMonitor.stop()
        store.clear()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        dragMonitor?.refreshPermissionStatus()
        launchAtLoginController?.refresh()
    }

    private func configureStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.isVisible = true
        if let button = statusItem.button {
            let image = NSImage(
                systemSymbolName: "tray.full.fill",
                accessibilityDescription: "Bandeja"
            )
            image?.isTemplate = true
            button.image = image
            button.imagePosition = .imageLeading
            button.title = "Bandeja"
            button.font = .systemFont(ofSize: 12, weight: .semibold)
            button.toolTip = "Bandeja temporal"
            button.setAccessibilityLabel("Bandeja, utilidad temporal de archivos")
        }

        let menu = NSMenu(title: "Bandeja")
        menu.delegate = self

        let showItem = NSMenuItem(
            title: "Mostrar bandeja",
            action: #selector(showTray),
            keyEquivalent: ""
        )
        showItem.target = self
        menu.addItem(showItem)

        let gestureStatusItem = NSMenuItem(
            title: "Comprobando detección global…",
            action: nil,
            keyEquivalent: ""
        )
        gestureStatusItem.isEnabled = false
        menu.addItem(gestureStatusItem)
        gestureStatusMenuItem = gestureStatusItem

        let permissionItem = NSMenuItem(
            title: "Dar permiso de Monitorización de entrada…",
            action: #selector(requestInputMonitoringPermission),
            keyEquivalent: ""
        )
        permissionItem.target = self
        menu.addItem(permissionItem)
        requestPermissionMenuItem = permissionItem
        menu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: "Ajustes…",
            action: #selector(showSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        let sensitivityItem = NSMenuItem(title: "Sensibilidad", action: nil, keyEquivalent: "")
        let sensitivitySubmenu = NSMenu(title: "Sensibilidad")
        for sensitivity in GlobalDragMonitor.Sensitivity.allCases {
            let item = NSMenuItem(
                title: sensitivity.rawValue,
                action: #selector(changeSensitivity(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = sensitivity.rawValue
            sensitivitySubmenu.addItem(item)
        }
        sensitivityItem.submenu = sensitivitySubmenu
        sensitivityMenu = sensitivitySubmenu
        menu.addItem(sensitivityItem)

        let privacyItem = NSMenuItem(
            title: "Solo observa el ratón · nunca el teclado",
            action: nil,
            keyEquivalent: ""
        )
        privacyItem.isEnabled = false
        menu.addItem(privacyItem)
        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Salir de Bandeja",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)
        statusItem.menu = menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        dragMonitor.refreshPermissionStatus()
        for item in sensitivityMenu?.items ?? [] {
            item.state = item.title == settings.shakeSensitivity.rawValue ? .on : .off
        }
    }

    @objc private func showTray() {
        panelController.showNearCursor()
    }

    @objc private func showSettings() {
        dragMonitor.refreshPermissionStatus()
        launchAtLoginController.refresh()
        settingsWindowController.show()
    }

    @objc private func requestInputMonitoringPermission() {
        dragMonitor.requestInputMonitoringAccess(openSystemSettingsOnFailure: true)
    }

    @objc private func changeSensitivity(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let sensitivity = GlobalDragMonitor.Sensitivity(rawValue: rawValue) else { return }
        settings.shakeSensitivity = sensitivity
    }

    private func observeSettings() {
        settings.$shakeSensitivity
            .removeDuplicates()
            .sink { [weak self] sensitivity in
                self?.dragMonitor.setSensitivity(sensitivity)
            }
            .store(in: &subscriptions)

        Publishers.CombineLatest(settings.$shortcutEnabled, settings.$shortcutPreset)
            .sink { [weak self] values in
                self?.configureShortcut(enabled: values.0, preset: values.1)
            }
            .store(in: &subscriptions)

        settings.$screenshotDetectionEnabled
            .removeDuplicates()
            .sink { [weak self] isEnabled in
                guard let self else { return }
                if isEnabled {
                    self.screenshotMonitor.start()
                } else {
                    self.screenshotMonitor.stop()
                }
            }
            .store(in: &subscriptions)
    }

    private func configureShortcut(enabled: Bool, preset: GlobalShortcutPreset) {
        guard enabled else {
            shortcutMonitor.unregister()
            settings.setShortcutStatus(nil)
            return
        }

        switch shortcutMonitor.register(preset) {
        case .registered:
            settings.setShortcutStatus(nil)
        case .conflict:
            settings.setShortcutStatus("Ese atajo ya está en uso. Elige otro.")
        case let .failed(status):
            settings.setShortcutStatus("No se pudo registrar el atajo (código \(status)).")
        }
    }

    private func handleScreenshotStatus(_ status: ScreenshotMonitor.Status) {
        switch status {
        case .unavailable:
            settings.setScreenshotStatus("Spotlight no está disponible para detectar capturas.")
        case .stopped, .searching, .monitoring:
            settings.setScreenshotStatus(nil)
        }
    }

    private func handleGestureMonitoringStatus(_ status: GestureMonitoringStatus) {
        settings.setGestureMonitoringStatus(status)

        switch status {
        case .checking:
            gestureStatusMenuItem?.title = "Comprobando detección global…"
            requestPermissionMenuItem?.isHidden = false
        case .fullAccess:
            gestureStatusMenuItem?.title = "Detección global activa · sacude ↔ al arrastrar"
            requestPermissionMenuItem?.isHidden = true
        case .permissionRequired:
            gestureStatusMenuItem?.title = "Detección limitada · falta permiso"
            requestPermissionMenuItem?.isHidden = false
        case .fallback:
            gestureStatusMenuItem?.title = "Detección limitada · monitor no disponible"
            requestPermissionMenuItem?.isHidden = false
        }
    }
}
