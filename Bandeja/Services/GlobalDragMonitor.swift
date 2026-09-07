import AppKit

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
    private let onShake: (CGPoint) -> Void
    private let onDragEnded: () -> Void
    private(set) var sensitivity: Sensitivity

    init(
        sensitivity: Sensitivity = .balanced,
        onShake: @escaping (CGPoint) -> Void,
        onDragEnded: @escaping () -> Void = {}
    ) {
        self.sensitivity = sensitivity
        self.sampleProcessor = GlobalDragSampleProcessor(configuration: sensitivity.configuration)
        self.onShake = onShake
        self.onDragEnded = onDragEnded
    }

    func start() {
        guard pollingTimer == nil else { return }

        // A passive global NSEvent monitor can stop receiving mouseDragged events while
        // another app owns an AppKit drag session. Sampling the public global cursor and
        // button state avoids that gap and does not install an event tap or request
        // Accessibility/Input Monitoring permission.
        let timer = Timer(timeInterval: 1.0 / 90.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.sampleMouseState()
            }
        }
        pollingTimer = timer
        RunLoop.main.add(timer, forMode: .common)
        sampleMouseState()
    }

    func stop() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        sampleProcessor.reset(configuration: sensitivity.configuration)
    }

    func setSensitivity(_ sensitivity: Sensitivity) {
        self.sensitivity = sensitivity
        sampleProcessor.reset(configuration: sensitivity.configuration)
    }

    private func sampleMouseState() {
        let point = NSEvent.mouseLocation
        let isLeftButtonPressed = NSEvent.pressedMouseButtons & 1 == 1
        let action = sampleProcessor.process(
            isLeftButtonPressed: isLeftButtonPressed,
            point: point,
            timestamp: ProcessInfo.processInfo.systemUptime
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

    deinit {
        pollingTimer?.invalidate()
    }
}
