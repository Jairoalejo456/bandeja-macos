import AppKit

enum GestureMonitoringStatus: Equatable {
    case checking
    case fullAccess
    case permissionRequired
    case fallback
}

private final class GlobalDragEventTapContext {
    let handler: (CGEventType, CGPoint?, TimeInterval?) -> Void

    init(handler: @escaping (CGEventType, CGPoint?, TimeInterval?) -> Void) {
        self.handler = handler
    }
}

private let globalDragEventTapCallback: CGEventTapCallBack = { _, type, event, userInfo in
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let context = Unmanaged<GlobalDragEventTapContext>
        .fromOpaque(userInfo)
        .takeUnretainedValue()

    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        context.handler(type, nil, nil)
        return Unmanaged.passUnretained(event)
    }

    // CGEvent uses a top-left origin. NSEvent performs the screen-coordinate
    // conversion expected by NSPanel positioning and the shake detector.
    let point = NSEvent(cgEvent: event)?.locationInWindow ?? event.location
    let timestamp = TimeInterval(event.timestamp) / 1_000_000_000
    context.handler(type, point, timestamp)
    return Unmanaged.passUnretained(event)
}

enum GlobalDragSampleAction: Equatable {
    case none
    case shake(CGPoint)
    case dragEnded
}

struct GlobalDragSampleProcessor {
    private var detector: ShakeDetector
    private(set) var isLeftButtonPressed = false

    init(configuration: ShakeConfiguration) {
        detector = ShakeDetector(configuration: configuration)
    }

    mutating func process(
        isLeftButtonPressed: Bool,
        point: CGPoint,
        timestamp: TimeInterval
    ) -> GlobalDragSampleAction {
        if isLeftButtonPressed {
            if !self.isLeftButtonPressed {
                self.isLeftButtonPressed = true
                detector.beginDrag(at: point, timestamp: timestamp)
                return .none
            }

            return detector.updateDrag(at: point, timestamp: timestamp) ? .shake(point) : .none
        }

        guard self.isLeftButtonPressed else { return .none }
        self.isLeftButtonPressed = false
        detector.endDrag()
        return .dragEnded
    }

    mutating func reset(configuration: ShakeConfiguration) {
        isLeftButtonPressed = false
        detector.endDrag()
        detector.configuration = configuration
    }
}

@MainActor
final class GlobalDragMonitor {
    enum Sensitivity: String, CaseIterable {
        case low = "Baja"
        case balanced = "Equilibrada"
        case high = "Alta"

        var configuration: ShakeConfiguration {
            switch self {
            case .low: return .lowSensitivity
            case .balanced: return .balanced
            case .high: return .highSensitivity
            }
        }
    }

    private var sampleProcessor: GlobalDragSampleProcessor
    private var pollingTimer: Timer?
    private var eventTap: CFMachPort?
    private var eventTapSource: CFRunLoopSource?
    private var isStarted = false
    private let onShake: (CGPoint) -> Void
    private let onDragEnded: () -> Void
    private let onStatusChange: (GestureMonitoringStatus) -> Void
    private(set) var sensitivity: Sensitivity

    static let monitoredEventMask: CGEventMask = [
        CGEventType.leftMouseDown,
        .leftMouseDragged,
        .leftMouseUp
    ].reduce(0) { mask, type in
        mask | (CGEventMask(1) << type.rawValue)
    }

    private lazy var eventTapContext = GlobalDragEventTapContext { [weak self] type, point, timestamp in
        Task { @MainActor [weak self] in
            self?.handleEventTap(type: type, point: point, timestamp: timestamp)
        }
    }

    init(
        sensitivity: Sensitivity = .balanced,
        onShake: @escaping (CGPoint) -> Void,
        onDragEnded: @escaping () -> Void = {},
        onStatusChange: @escaping (GestureMonitoringStatus) -> Void = { _ in }
    ) {
        self.sensitivity = sensitivity
        self.sampleProcessor = GlobalDragSampleProcessor(configuration: sensitivity.configuration)
        self.onShake = onShake
        self.onDragEnded = onDragEnded
        self.onStatusChange = onStatusChange
    }

    func start(requestPermission: Bool = true) {
        guard !isStarted else { return }
        isStarted = true

        if CGPreflightListenEventAccess(), installEventTap() {
            onStatusChange(.fullAccess)
            return
        }

        startPollingFallback()
        onStatusChange(CGPreflightListenEventAccess() ? .fallback : .permissionRequired)

        guard requestPermission, !CGPreflightListenEventAccess() else { return }
        // Delay the native prompt until the menu-bar item has appeared, so the user
        // can identify which app is asking and always has a visible recovery path.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.requestInputMonitoringAccess(openSystemSettingsOnFailure: false)
        }
    }

    func refreshPermissionStatus() {
        guard isStarted else { return }
        guard CGPreflightListenEventAccess() else {
            removeEventTap()
            startPollingFallback()
            onStatusChange(.permissionRequired)
            return
        }

        if eventTap != nil || installEventTap() {
            stopPollingFallback()
            onStatusChange(.fullAccess)
        } else {
            startPollingFallback()
            onStatusChange(.fallback)
        }
    }

    func requestInputMonitoringAccess(openSystemSettingsOnFailure: Bool = true) {
        guard isStarted else { return }
        let granted = CGRequestListenEventAccess()
        refreshPermissionStatus()

        if !granted, openSystemSettingsOnFailure {
            openInputMonitoringSettings()
        }

        // macOS can update TCC asynchronously after the user changes the switch.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.refreshPermissionStatus()
        }
    }

    func stop() {
        isStarted = false
        removeEventTap()
        stopPollingFallback()
        sampleProcessor.reset(configuration: sensitivity.configuration)
    }

    func setSensitivity(_ sensitivity: Sensitivity) {
        self.sensitivity = sensitivity
        sampleProcessor.reset(configuration: sensitivity.configuration)
    }

    private func installEventTap() -> Bool {
        guard eventTap == nil else { return true }

        let contextPointer = Unmanaged.passUnretained(eventTapContext).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: Self.monitoredEventMask,
            callback: globalDragEventTapCallback,
            userInfo: contextPointer
        ) else {
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        eventTap = tap
        eventTapSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        sampleProcessor.reset(configuration: sensitivity.configuration)
        return true
    }

    private func removeEventTap() {
        if let source = eventTapSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
        }
        eventTapSource = nil
        eventTap = nil
    }

    private func handleEventTap(
        type: CGEventType,
        point: CGPoint?,
        timestamp: TimeInterval?
    ) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            } else {
                refreshPermissionStatus()
            }
            return
        }

        guard let point, let timestamp else { return }
        switch type {
        case .leftMouseDown, .leftMouseDragged:
            processSample(isLeftButtonPressed: true, point: point, timestamp: timestamp)
        case .leftMouseUp:
            processSample(isLeftButtonPressed: false, point: point, timestamp: timestamp)
        default:
            break
        }
    }

    private func startPollingFallback() {
        guard pollingTimer == nil else { return }

        let timer = Timer(timeInterval: 1.0 / 90.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.sampleMouseState()
            }
        }
        pollingTimer = timer
        RunLoop.main.add(timer, forMode: .common)
        sampleMouseState()
    }

    private func stopPollingFallback() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }

    private func sampleMouseState() {
        let point = NSEvent.mouseLocation
        let isLeftButtonPressed = NSEvent.pressedMouseButtons & 1 == 1
        processSample(
            isLeftButtonPressed: isLeftButtonPressed,
            point: point,
            timestamp: ProcessInfo.processInfo.systemUptime
        )
    }

    private func processSample(
        isLeftButtonPressed: Bool,
        point: CGPoint,
        timestamp: TimeInterval
    ) {
        let action = sampleProcessor.process(
            isLeftButtonPressed: isLeftButtonPressed,
            point: point,
            timestamp: timestamp
        )

        switch action {
        case .none:
            break
        case let .shake(cursor):
            onShake(cursor)
        case .dragEnded:
            onDragEnded()
        }
    }

    private func openInputMonitoringSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    deinit {
        pollingTimer?.invalidate()
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
        }
    }
}
