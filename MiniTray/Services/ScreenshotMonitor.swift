import Foundation

struct ScreenshotCandidateFilter {
    static func shouldHandle(
        isScreenCapture: Bool,
        url: URL?,
        creationDate: Date?,
        now: Date = Date()
    ) -> Bool {
        guard isScreenCapture, let url, url.isFileURL else { return false }
        guard let creationDate else { return true }
        let age = now.timeIntervalSince(creationDate)
        return age >= -2 && age <= 30
    }

    static func shouldHandleInitialCandidate(
        isScreenCapture: Bool,
        url: URL?,
        creationDate: Date?,
        monitoringStartedAt: Date,
        now: Date = Date()
    ) -> Bool {
        guard let creationDate,
              creationDate >= monitoringStartedAt.addingTimeInterval(-2) else { return false }
        return shouldHandle(
            isScreenCapture: isScreenCapture,
            url: url,
            creationDate: creationDate,
            now: now
        )
    }
}

@MainActor
final class ScreenshotMonitor {
    enum Status: Equatable {
        case stopped
        case searching
        case monitoring
        case unavailable
    }

    var onScreenshot: ((URL) -> Void)?
    var onStatusChange: ((Status) -> Void)?

    private var query: NSMetadataQuery?
    private var observers: [NSObjectProtocol] = []
    private var knownPaths: Set<String> = []
    private var initialGatherFinished = false
    private var monitoringStartedAt: Date?

    func start() {
        guard query == nil else { return }
        let query = NSMetadataQuery()
        query.predicate = NSPredicate(format: "%K == YES", "kMDItemIsScreenCapture")
        query.searchScopes = [NSMetadataQueryLocalComputerScope]
        self.query = query
        initialGatherFinished = false
        monitoringStartedAt = Date()
        knownPaths.removeAll()

        let center = NotificationCenter.default
        observers = [
            center.addObserver(
                forName: .NSMetadataQueryDidFinishGathering,
                object: query,
                queue: .main
            ) { [weak self] notification in
                MainActor.assumeIsolated { self?.didFinishGathering(notification) }
            },
            center.addObserver(
                forName: .NSMetadataQueryDidUpdate,
                object: query,
                queue: .main
            ) { [weak self] notification in
                MainActor.assumeIsolated { self?.didUpdate(notification) }
            }
        ]

        onStatusChange?(.searching)
        guard query.start() else {
            stop()
            onStatusChange?(.unavailable)
            return
        }
    }

    func stop() {
        if let query {
            query.stop()
        }
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        observers.removeAll()
        query = nil
        knownPaths.removeAll()
        initialGatherFinished = false
        monitoringStartedAt = nil
        onStatusChange?(.stopped)
    }

    private func didFinishGathering(_ notification: Notification) {
        guard let query = notification.object as? NSMetadataQuery else { return }
        query.disableUpdates()
        let now = Date()
        let startedAt = monitoringStartedAt ?? now
        var capturesCreatedWhileGathering: [URL] = []

        for index in 0..<query.resultCount {
            guard let item = query.result(at: index) as? NSMetadataItem,
                  let url = fileURL(from: item) else { continue }
            knownPaths.insert(url.standardizedFileURL.path)

            let isScreenshot = (item.value(forAttribute: "kMDItemIsScreenCapture") as? NSNumber)?.boolValue ?? false
            let creationDate = item.value(forAttribute: NSMetadataItemFSCreationDateKey) as? Date
            if ScreenshotCandidateFilter.shouldHandleInitialCandidate(
                isScreenCapture: isScreenshot,
                url: url,
                creationDate: creationDate,
                monitoringStartedAt: startedAt,
                now: now
            ) {
                capturesCreatedWhileGathering.append(url)
            }
        }

        initialGatherFinished = true
        query.enableUpdates()
        onStatusChange?(.monitoring)
        capturesCreatedWhileGathering.forEach { onScreenshot?($0) }
    }

    private func didUpdate(_ notification: Notification) {
        guard initialGatherFinished else { return }
        let addedItems = notification.userInfo?[NSMetadataQueryUpdateAddedItemsKey] as? [NSMetadataItem] ?? []
        for item in addedItems {
            guard let url = fileURL(from: item) else { continue }
            let path = url.standardizedFileURL.path
            guard !knownPaths.contains(path) else { continue }
            knownPaths.insert(path)

            let isScreenshot = (item.value(forAttribute: "kMDItemIsScreenCapture") as? NSNumber)?.boolValue ?? false
            let creationDate = item.value(forAttribute: NSMetadataItemFSCreationDateKey) as? Date
            if ScreenshotCandidateFilter.shouldHandle(
                isScreenCapture: isScreenshot,
                url: url,
                creationDate: creationDate
            ) {
                onScreenshot?(url)
            }
        }
    }

    private func fileURL(from item: NSMetadataItem) -> URL? {
        if let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL {
            return url
        }
        if let value = item.value(forAttribute: NSMetadataItemURLKey) as? String {
            return URL(string: value)
        }
        if let path = item.value(forAttribute: NSMetadataItemPathKey) as? String {
            return URL(fileURLWithPath: path)
        }
        return nil
    }

    deinit {
        if let query { query.stop() }
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
    }
}
