import CoreGraphics
import Foundation

struct ShakeConfiguration: Equatable {
    var minimumSegmentDistance: CGFloat
    var maximumSegmentDuration: TimeInterval
    var gestureWindow: TimeInterval
    var requiredReversals: Int
    var minimumTotalHorizontalTravel: CGFloat
    var maximumVerticalToHorizontalRatio: CGFloat
    var minimumSampleDistance: CGFloat
    var cooldown: TimeInterval

    static let balanced = ShakeConfiguration(
        minimumSegmentDistance: 28,
        maximumSegmentDuration: 0.24,
        gestureWindow: 0.72,
        requiredReversals: 3,
        minimumTotalHorizontalTravel: 120,
        maximumVerticalToHorizontalRatio: 0.78,
        minimumSampleDistance: 1.5,
        cooldown: 0.9
    )

    static let lowSensitivity = ShakeConfiguration(
        minimumSegmentDistance: 36,
        maximumSegmentDuration: 0.21,
        gestureWindow: 0.64,
        requiredReversals: 4,
        minimumTotalHorizontalTravel: 165,
        maximumVerticalToHorizontalRatio: 0.62,
        minimumSampleDistance: 2,
        cooldown: 1.0
    )

    static let highSensitivity = ShakeConfiguration(
        minimumSegmentDistance: 22,
        maximumSegmentDuration: 0.28,
        gestureWindow: 0.82,
        requiredReversals: 3,
        minimumTotalHorizontalTravel: 94,
        maximumVerticalToHorizontalRatio: 0.95,
        minimumSampleDistance: 1,
        cooldown: 0.75
    )
}

struct ShakeDetector {
    private struct TravelSample {
        let time: TimeInterval
        let horizontal: CGFloat
        let vertical: CGFloat
    }

    private enum Direction: Int {
        case left = -1
        case right = 1
    }

    var configuration: ShakeConfiguration

    private(set) var isDragging = false
    private var lastPoint: CGPoint?
    private var lastTimestamp: TimeInterval?
    private var currentDirection: Direction?
    private var segmentStartedAt: TimeInterval?
    private var segmentDistance: CGFloat = 0
    private var reversalTimes: [TimeInterval] = []
    private var travelSamples: [TravelSample] = []
    private var lastTriggerTimestamp: TimeInterval = -.infinity

    init(configuration: ShakeConfiguration = .balanced) {
        self.configuration = configuration
    }

    mutating func beginDrag(at point: CGPoint, timestamp: TimeInterval) {
        isDragging = true
        resetMotion(keeping: point, timestamp: timestamp)
    }

    mutating func endDrag() {
        isDragging = false
        resetMotion(keeping: nil, timestamp: nil)
    }

    mutating func updateDrag(at point: CGPoint, timestamp: TimeInterval) -> Bool {
        guard isDragging, let lastPoint, let lastTimestamp else { return false }

        let elapsed = timestamp - lastTimestamp
        guard elapsed >= 0 else {
            resetMotion(keeping: point, timestamp: timestamp)
            return false
        }

        if elapsed > configuration.gestureWindow {
            resetMotion(keeping: point, timestamp: timestamp)
            return false
        }

        let dx = point.x - lastPoint.x
        let dy = point.y - lastPoint.y
        self.lastPoint = point
        self.lastTimestamp = timestamp

        let horizontal = abs(dx)
        let vertical = abs(dy)
        guard horizontal + vertical >= configuration.minimumSampleDistance else { return false }

        travelSamples.append(TravelSample(time: timestamp, horizontal: horizontal, vertical: vertical))
        pruneHistory(at: timestamp)

        guard horizontal >= configuration.minimumSampleDistance else { return false }
        let incomingDirection: Direction = dx < 0 ? .left : .right

        guard let direction = currentDirection else {
            currentDirection = incomingDirection
            segmentStartedAt = timestamp
            segmentDistance = horizontal
            return false
        }

        if incomingDirection == direction {
            segmentDistance += horizontal
            return false
        }

        let segmentDuration = timestamp - (segmentStartedAt ?? timestamp)
        let isDeliberateSegment = segmentDistance >= configuration.minimumSegmentDistance
            && segmentDuration <= configuration.maximumSegmentDuration

        currentDirection = incomingDirection
        segmentStartedAt = timestamp
        segmentDistance = horizontal

        guard isDeliberateSegment else {
            reversalTimes.removeAll()
            return false
        }

        reversalTimes.append(timestamp)
        reversalTimes.removeAll { timestamp - $0 > configuration.gestureWindow }

        guard reversalTimes.count >= configuration.requiredReversals else { return false }
        guard timestamp - lastTriggerTimestamp >= configuration.cooldown else { return false }

        let firstReversal = reversalTimes[reversalTimes.count - configuration.requiredReversals]
        let analysisStart = max(timestamp - configuration.gestureWindow, firstReversal - configuration.maximumSegmentDuration)
        let recentTravel = travelSamples.filter { $0.time >= analysisStart }
        let horizontalTravel = recentTravel.reduce(CGFloat.zero) { $0 + $1.horizontal }
        let verticalTravel = recentTravel.reduce(CGFloat.zero) { $0 + $1.vertical }

        guard horizontalTravel >= configuration.minimumTotalHorizontalTravel else { return false }
        guard verticalTravel <= horizontalTravel * configuration.maximumVerticalToHorizontalRatio else { return false }

        lastTriggerTimestamp = timestamp
        resetGestureAfterTrigger(keeping: point, timestamp: timestamp)
        return true
    }

    private mutating func pruneHistory(at timestamp: TimeInterval) {
        travelSamples.removeAll { timestamp - $0.time > configuration.gestureWindow }
        reversalTimes.removeAll { timestamp - $0 > configuration.gestureWindow }
    }

    private mutating func resetMotion(keeping point: CGPoint?, timestamp: TimeInterval?) {
        lastPoint = point
        lastTimestamp = timestamp
        currentDirection = nil
        segmentStartedAt = timestamp
        segmentDistance = 0
        reversalTimes.removeAll()
        travelSamples.removeAll()
    }

    private mutating func resetGestureAfterTrigger(keeping point: CGPoint, timestamp: TimeInterval) {
        lastPoint = point
        lastTimestamp = timestamp
        currentDirection = nil
        segmentStartedAt = timestamp
        segmentDistance = 0
        reversalTimes.removeAll()
        travelSamples.removeAll()
    }
}
