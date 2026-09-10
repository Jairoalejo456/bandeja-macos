import AppKit
import SwiftUI

/// Cubic Bézier evaluated in time (x), not in its curve parameter. Values above
/// one are intentional: the supplied spring curve has a small overshoot.
struct MotionCurve: Equatable {
    let x1: Double
    let y1: Double
    let x2: Double
    let y2: Double

    static let spring = Self(x1: 0.2, y1: 1.1, x2: 0.3, y2: 1)
    static let glide = Self(x1: 0.32, y1: 0.72, x2: 0, y2: 1)
    static let exit = Self(x1: 0.4, y1: 0, x2: 0.75, y2: 0.2)
    static let travel = Self(x1: 0.4, y1: 0, x2: 0.28, y2: 1)
    static let itemShare = Self(x1: 0.3, y1: 0, x2: 0.2, y2: 1)
    static let trayShare = Self(x1: 0.32, y1: 0, x2: 0.24, y2: 1)

    func value(at time: Double) -> Double {
        guard time > 0 else { return 0 }
        guard time < 1 else { return 1 }
        func cubic(_ t: Double, _ a: Double, _ b: Double) -> Double {
            3 * (1 - t) * (1 - t) * t * a + 3 * (1 - t) * t * t * b + t * t * t
        }
        var lower = 0.0
        var upper = 1.0
        for _ in 0..<24 {
            let middle = (lower + upper) / 2
            if cubic(middle, x1, x2) < time { lower = middle } else { upper = middle }
        }
        return cubic((lower + upper) / 2, y1, y2)
    }
}

struct MotionPose: Equatable {
    var opacity: Double = 1
    var scale: CGFloat = 1
    var x: CGFloat = 0
    var y: CGFloat = 0 // positive down, as in the reference CSS
    var blur: CGFloat = 0
    var rotation: Double = 0

    static let identity = Self()

    func interpolated(to end: Self, progress p: Double) -> Self {
        Self(opacity: opacity + (end.opacity - opacity) * p,
             scale: scale + (end.scale - scale) * p,
             x: x + (end.x - x) * p, y: y + (end.y - y) * p,
             blur: max(0, blur + (end.blur - blur) * p),
             rotation: rotation + (end.rotation - rotation) * p)
    }
}

struct MotionKeyframe {
    let time: Double
    let pose: MotionPose
}

struct MotionTrack {
    let duration: TimeInterval
    let curve: MotionCurve
    let frames: [MotionKeyframe]

    func pose(at elapsed: TimeInterval) -> MotionPose {
        let progress = max(0, min(1, elapsed / duration))
        guard let last = frames.last, let first = frames.first else { return .identity }
        guard progress < last.time else { return last.pose }
        for index in 1..<frames.count where progress <= frames[index].time {
            let a = frames[index - 1], b = frames[index]
            let p = (progress - a.time) / (b.time - a.time)
            return a.pose.interpolated(to: b.pose, progress: curve.value(at: p))
        }
        return first.pose
    }

    static func between(_ start: MotionPose, _ end: MotionPose,
                        duration: TimeInterval, curve: MotionCurve = .glide) -> Self {
        Self(duration: duration, curve: curve, frames: [
            MotionKeyframe(time: 0, pose: start), MotionKeyframe(time: 1, pose: end)
        ])
    }
}

enum TrayMotion {
    static func entrance(reduced: Bool) -> MotionTrack {
        if reduced { return .between(MotionPose(opacity: 0), .identity, duration: 0.12) }
        return MotionTrack(duration: 0.34, curve: .spring, frames: [
            .init(time: 0, pose: MotionPose(opacity: 0, scale: 0.72, y: 10, blur: 10)),
            .init(time: 0.55, pose: MotionPose(scale: 1.02, y: -2)),
            .init(time: 1, pose: .identity)
        ])
    }

    static func receive(reduced: Bool) -> MotionTrack {
        if reduced { return .between(MotionPose(opacity: 0.8), .identity, duration: 0.12) }
        return MotionTrack(duration: 0.26, curve: .spring, frames: [
            .init(time: 0, pose: .identity),
            .init(time: 0.42, pose: MotionPose(scale: 1.035)),
            .init(time: 1, pose: .identity)
        ])
    }

    static func incomingItem(reduced: Bool) -> MotionTrack {
        .between(MotionPose(opacity: 0, scale: reduced ? 1 : 0.86,
                            y: reduced ? 0 : -22, blur: reduced ? 0 : 4),
                 .identity, duration: reduced ? 0.12 : 0.24, curve: .spring)
    }

    static func exit(from pose: MotionPose = .identity, reduced: Bool) -> MotionTrack {
        .between(reduced ? MotionPose(opacity: pose.opacity) : pose,
                 MotionPose(opacity: 0, scale: reduced ? 1 : 0.9,
                            y: reduced ? 0 : 6, blur: reduced ? 0 : 6),
                 duration: reduced ? 0.12 : 0.2, curve: .exit)
    }

    static func shareTray(reduced: Bool) -> MotionTrack {
        .between(.identity, MotionPose(opacity: 0, scale: reduced ? 1 : 0.92,
                                     y: reduced ? 0 : -34, blur: reduced ? 0 : 5),
                 duration: reduced ? 0.12 : 0.34, curve: .trayShare)
    }

    static func shareItem(reduced: Bool) -> MotionTrack {
        .between(.identity, MotionPose(opacity: 0, scale: reduced ? 1 : 0.86,
                                     y: reduced ? 0 : -46),
                 duration: reduced ? 0.12 : 0.24, curve: .itemShare)
    }

    static func folder(dx: CGFloat, dy: CGFloat) -> MotionTrack {
        MotionTrack(duration: 0.38, curve: .travel, frames: [
            .init(time: 0, pose: .identity),
            .init(time: 0.18, pose: MotionPose(scale: 1.06, x: 4, y: -10, rotation: -3)),
            .init(time: 0.82, pose: MotionPose(opacity: 0.9, scale: 0.62, x: dx, y: dy, rotation: 1)),
            .init(time: 1, pose: MotionPose(opacity: 0, scale: 0.46, x: dx, y: dy + 2, blur: 3, rotation: 1))
        ])
    }

    static func itemDelay(index: Int, sharing: Bool) -> TimeInterval {
        min(Double(max(0, index)) * (sharing ? 0.045 : 0.04), sharing ? 0.18 : 0.24)
    }

    static func frame(from start: CGRect, to end: CGRect, progress: Double) -> CGRect {
        let p = MotionCurve.glide.value(at: progress)
        return CGRect(x: start.minX + (end.minX - start.minX) * p,
                      y: start.minY + (end.minY - start.minY) * p,
                      width: start.width + (end.width - start.width) * p,
                      height: start.height + (end.height - start.height) * p)
    }
}

/// One common-run-loop clock, with replaceable channels. Cancelling a channel
/// removes its completion too; no delayed close can affect a reopened tray.
@MainActor
final class TrayMotionClock {
    private struct Job {
        let id = UUID()
        let start: TimeInterval
        let duration: TimeInterval
        let update: (TimeInterval) -> Void
        let completion: () -> Void
    }
    private var jobs: [String: Job] = [:]
    private var timer: Timer?
    var now: () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    var hasWork: Bool { !jobs.isEmpty }

    func run(_ key: String, duration: TimeInterval, delay: TimeInterval = 0,
             update: @escaping (TimeInterval) -> Void, completion: @escaping () -> Void = {}) {
        jobs[key] = Job(start: now() + delay, duration: duration, update: update, completion: completion)
        update(0)
        if timer == nil {
            let timer = Timer(timeInterval: 1.0 / 120, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.tick() }
            }
            timer.tolerance = 0.002
            self.timer = timer
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    func cancel(_ key: String) {
        jobs.removeValue(forKey: key)
        stopIfIdle()
    }

    func cancelAll() {
        jobs.removeAll()
        stopIfIdle()
    }

    func tick() {
        let time = now()
        for (key, job) in jobs {
            guard jobs[key]?.id == job.id, time >= job.start else { continue }
            let elapsed = min(job.duration, time - job.start)
            job.update(elapsed)
            if elapsed >= job.duration, jobs[key]?.id == job.id {
                jobs.removeValue(forKey: key)
                job.completion()
            }
        }
        stopIfIdle()
    }

    private func stopIfIdle() {
        if jobs.isEmpty { timer?.invalidate(); timer = nil }
    }

    deinit { timer?.invalidate() }
}

@MainActor
final class TrayVisualState: ObservableObject {
    @Published var pose = MotionPose.identity
    @Published var itemPoses: [UUID: MotionPose] = [:]
    @Published var retainedItems: [TrayItem]?
    @Published var retainedExpanded: Bool?
    @Published var outgoingExpanded: Bool?
    @Published var outgoingSize: CGSize = .zero
    @Published var outgoingOpacity: Double = 0
    @Published var contentOpacity: Double = 1
    @Published var contentSize: CGSize?
    @Published var sweep: Double?
}

struct MotionPoseModifier: ViewModifier {
    let pose: MotionPose
    func body(content: Content) -> some View {
        content.scaleEffect(pose.scale)
            .rotationEffect(.degrees(pose.rotation))
            .offset(x: pose.x, y: pose.y)
            .blur(radius: pose.blur)
            .opacity(pose.opacity)
    }
}
