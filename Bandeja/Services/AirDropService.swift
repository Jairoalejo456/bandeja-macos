import AppKit

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
