import AppKit

/// Retained independently of the menu/SwiftUI branch while a native composer is
/// open. The IDs are a snapshot: completion cannot discard subsequently added files.
@MainActor
final class TraySharingSession: NSObject, NSSharingServiceDelegate, @preconcurrency NSSharingServicePickerDelegate {
    private static var active: [UUID: TraySharingSession] = [:]
    private let id = UUID()
    private let trayItems: [TrayItem]
    private let onShared: (Set<UUID>) -> Void
    private var service: NSSharingService?

    init(items: [TrayItem], onShared: @escaping (Set<UUID>) -> Void) {
        trayItems = items
        self.onShared = onShared
    }

    func perform(_ service: NSSharingService, values: [Any]) {
        guard service.canPerform(withItems: values) else { return }
        retain(for: service)
        service.delegate = self
        service.perform(withItems: values)
    }

    private func retain(for service: NSSharingService) {
        self.service = service
        Self.active[id] = self
    }

    func sharingServicePicker(_ sharingServicePicker: NSSharingServicePicker,
                              delegateFor sharingService: NSSharingService) -> NSSharingServiceDelegate? {
        self
    }

    func sharingService(_ sharingService: NSSharingService, willShareItems items: [Any]) {
        retain(for: sharingService)
    }

    func sharingService(_ sharingService: NSSharingService, didShareItems items: [Any]) {
        onShared(Set(trayItems.map(\.id)))
        finish()
    }

    func sharingService(_ sharingService: NSSharingService, didFailToShareItems items: [Any], error: Error) {
        // Cancellation/failure leaves the tray exactly as it was.
        finish()
    }

    private func finish() {
        service?.delegate = nil
        service = nil
        Self.active.removeValue(forKey: id)
    }
}

@MainActor
final class AirDropService: NSObject, NSSharingServiceDelegate {
    enum StartResult {
        case started
        case unavailable
        case noItems
    }

    var onCompletion: ((String) -> Void)?
    private var activeService: NSSharingService?

    func send(_ trayItems: [TrayItem]) -> StartResult {
        let items: [Any] = trayItems.compactMap { item in
            switch item.content {
            case let .file(url):
                return url as NSURL
            case let .image(_, image):
                return image
            }
        }

        guard !items.isEmpty else { return .noItems }
        guard let service = NSSharingService(named: .sendViaAirDrop),
              service.canPerform(withItems: items) else {
            return .unavailable
        }

        activeService = service
        service.delegate = self
        service.perform(withItems: items)
        return .started
    }

    func sharingService(_ sharingService: NSSharingService, didShareItems items: [Any]) {
        activeService = nil
        onCompletion?("AirDrop finalizó.")
    }

    func sharingService(
        _ sharingService: NSSharingService,
        didFailToShareItems items: [Any],
        error: Error
    ) {
        activeService = nil
        onCompletion?("AirDrop no se completó: \(error.localizedDescription)")
    }
}
