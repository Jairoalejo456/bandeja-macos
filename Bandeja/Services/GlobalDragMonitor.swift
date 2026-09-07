import AppKit

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

    private var detector: ShakeDetector
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private let onShake: (CGPoint) -> Void
    private let onDragEnded: () -> Void
    private(set) var sensitivity: Sensitivity

    init(
        sensitivity: Sensitivity = .balanced,
        onShake: @escaping (CGPoint) -> Void,
        onDragEnded: @escaping () -> Void = {}
    ) {
        self.sensitivity = sensitivity
        self.detector = ShakeDetector(configuration: sensitivity.configuration)
        self.onShake = onShake
        self.onDragEnded = onDragEnded
    }

    func start() {
        guard globalMonitor == nil, localMonitor == nil else { return }

        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .leftMouseDragged, .leftMouseUp]
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            Task { @MainActor in
                self?.handle(event)
            }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            self?.handle(event)
            return event
        }
    }

    func stop() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        globalMonitor = nil
        localMonitor = nil
        detector.endDrag()
    }

    func setSensitivity(_ sensitivity: Sensitivity) {
        self.sensitivity = sensitivity
        detector.endDrag()
        detector.configuration = sensitivity.configuration
    }

    private func handle(_ event: NSEvent) {
        let point = NSEvent.mouseLocation
        switch event.type {
        case .leftMouseDown:
            detector.beginDrag(at: point, timestamp: event.timestamp)
        case .leftMouseDragged:
            if !detector.isDragging {
                detector.beginDrag(at: point, timestamp: event.timestamp)
                return
            }
            if detector.updateDrag(at: point, timestamp: event.timestamp) {
                onShake(point)
            }
        case .leftMouseUp:
            detector.endDrag()
            onDragEnded()
        default:
            break
        }
    }

    deinit {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
    }
}
