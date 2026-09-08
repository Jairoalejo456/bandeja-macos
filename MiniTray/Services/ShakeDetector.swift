import CoreGraphics
import Foundation

struct ShakeConfiguration: Equatable {
    var minimumSegmentDistance: CGFloat
    var maximumSegmentDuration: TimeInterval
    var gestureWindow: TimeInterval
    var requiredReversals: Int
    var minimumTotalTravel: CGFloat
    var maximumReversalDotProduct: CGFloat
    var minimumSampleDistance: CGFloat
    var cooldown: TimeInterval

    static let balanced = ShakeConfiguration(
        minimumSegmentDistance: 28,
        maximumSegmentDuration: 0.24,
        gestureWindow: 0.72,
        requiredReversals: 3,
        minimumTotalTravel: 120,
        maximumReversalDotProduct: -0.35,
        minimumSampleDistance: 1.5,
        cooldown: 0.9
    )

    static let lowSensitivity = ShakeConfiguration(
        minimumSegmentDistance: 36,
        maximumSegmentDuration: 0.21,
        gestureWindow: 0.64,
        requiredReversals: 4,
        minimumTotalTravel: 165,
        maximumReversalDotProduct: -0.55,
        minimumSampleDistance: 2,
        cooldown: 1.0
    )

    static let highSensitivity = ShakeConfiguration(
        minimumSegmentDistance: 22,
        maximumSegmentDuration: 0.28,
        gestureWindow: 0.82,
        requiredReversals: 3,
        minimumTotalTravel: 94,
        maximumReversalDotProduct: -0.20,
        minimumSampleDistance: 1,
        cooldown: 0.75
    )
}

struct ShakeDetector {
    private struct TravelSample {
        let time: TimeInterval
        let distance: CGFloat
    }

    var configuration: ShakeConfiguration

    private(set) var isDragging = false
    private var lastPoint: CGPoint?
    private var lastTimestamp: TimeInterval?
    private var segmentStartedAt: TimeInterval?
    private var segmentVector = CGVector.zero
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

        let step = CGVector(dx: dx, dy: dy)
        let stepDistance = magnitude(of: step)
        guard stepDistance >= configuration.minimumSampleDistance else { return false }

        travelSamples.append(TravelSample(time: timestamp, distance: stepDistance))
        pruneHistory(at: timestamp)

        let currentMagnitude = magnitude(of: segmentVector)
        guard currentMagnitude > 0 else {
            segmentVector = step
            segmentStartedAt = timestamp
            return false
        }

        let normalizedDotProduct = dot(step, segmentVector) / (stepDistance * currentMagnitude)
        guard normalizedDotProduct <= configuration.maximumReversalDotProduct else {
            segmentVector.dx += step.dx
            segmentVector.dy += step.dy
            return false
        }

        let segmentDuration = timestamp - (segmentStartedAt ?? timestamp)
        let isDeliberateSegment = currentMagnitude >= configuration.minimumSegmentDistance
            && segmentDuration <= configuration.maximumSegmentDuration

        segmentStartedAt = timestamp
        segmentVector = step

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
        let totalTravel = recentTravel.reduce(CGFloat.zero) { $0 + $1.distance }

        guard totalTravel >= configuration.minimumTotalTravel else { return false }

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
        segmentStartedAt = timestamp
        segmentVector = .zero
        reversalTimes.removeAll()
        travelSamples.removeAll()
    }

    private mutating func resetGestureAfterTrigger(keeping point: CGPoint, timestamp: TimeInterval) {
        lastPoint = point
        lastTimestamp = timestamp
        segmentStartedAt = timestamp
        segmentVector = .zero
        reversalTimes.removeAll()
        travelSamples.removeAll()
    }

    private func magnitude(of vector: CGVector) -> CGFloat {
        sqrt(vector.dx * vector.dx + vector.dy * vector.dy)
    }

    private func dot(_ lhs: CGVector, _ rhs: CGVector) -> CGFloat {
        lhs.dx * rhs.dx + lhs.dy * rhs.dy
    }
}
