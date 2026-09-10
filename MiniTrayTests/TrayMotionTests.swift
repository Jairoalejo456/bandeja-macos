import AppKit
import XCTest
@testable import MiniTray

final class TrayMotionTests: XCTestCase {
    func testReferenceKeyframesAndDurations() {
        let entry = TrayMotion.entrance(reduced: false)
        XCTAssertEqual(entry.duration, 0.34)
        XCTAssertEqual(entry.pose(at: 0), MotionPose(opacity: 0, scale: 0.72, y: 10, blur: 10))
        XCTAssertEqual(entry.pose(at: 0.34 * 0.55).scale, 1.02, accuracy: 0.0001)
        XCTAssertEqual(entry.pose(at: 0.34), .identity)
        let receive = TrayMotion.receive(reduced: false)
        XCTAssertEqual(receive.pose(at: 0.26 * 0.42).scale, 1.035, accuracy: 0.0001)
        XCTAssertEqual(receive.pose(at: 0.26), .identity)
        XCTAssertEqual(TrayMotion.exit(reduced: false).pose(at: 0.2),
                       MotionPose(opacity: 0, scale: 0.9, y: 6, blur: 6))
        XCTAssertEqual(TrayMotion.shareTray(reduced: false).pose(at: 0.34),
                       MotionPose(opacity: 0, scale: 0.92, y: -34, blur: 5))
        XCTAssertEqual(TrayMotion.shareItem(reduced: false).pose(at: 0.24).y, -46)
    }

    func testFolderUsesRuntimeDisplacementAndExactAbsorptionEndpoint() {
        let track = TrayMotion.folder(dx: -160, dy: 92)
        XCTAssertEqual(track.pose(at: 0.38 * 0.18).y, -10, accuracy: 0.0001)
        XCTAssertEqual(track.pose(at: 0.38),
                       MotionPose(opacity: 0, scale: 0.46, x: -160, y: 94, blur: 3, rotation: 1))
    }

    func testCubicBezierSolvesTimeAndKeepsOvershoot() {
        let linear = MotionCurve(x1: 0.2, y1: 0.2, x2: 0.8, y2: 0.8)
        for t in stride(from: 0.0, through: 1.0, by: 0.01) {
            XCTAssertEqual(linear.value(at: t), t, accuracy: 0.00001)
        }
        XCTAssertGreaterThan(MotionCurve.spring.value(at: 0.65), 1)
        XCTAssertEqual(MotionCurve.glide.value(at: -1), 0)
        XCTAssertEqual(MotionCurve.glide.value(at: 2), 1)
    }

    func testReducedMotionIsOnlyOpacityForEveryTrack() {
        for track in [TrayMotion.entrance(reduced: true), TrayMotion.receive(reduced: true),
                      TrayMotion.incomingItem(reduced: true), TrayMotion.exit(reduced: true),
                      TrayMotion.shareTray(reduced: true), TrayMotion.shareItem(reduced: true)] {
            XCTAssertEqual(track.duration, 0.12)
            for elapsed in stride(from: 0.0, through: 0.12, by: 0.01) {
                let pose = track.pose(at: elapsed)
                XCTAssertEqual(pose.scale, 1)
                XCTAssertEqual(pose.y, 0)
                XCTAssertEqual(pose.blur, 0)
                XCTAssertEqual(pose.rotation, 0)
            }
        }
    }

    func testLargeBatchesHaveBoundedStaggers() {
        XCTAssertEqual(TrayMotion.itemDelay(index: 2, sharing: false), 0.08)
        XCTAssertEqual(TrayMotion.itemDelay(index: 2, sharing: true), 0.09)
        XCTAssertEqual(TrayMotion.itemDelay(index: 500, sharing: false), 0.24)
        XCTAssertLessThanOrEqual(TrayMotion.itemDelay(index: 500, sharing: true) + 0.24, 0.43)
    }

    @MainActor
    func testClockUsesElapsedTimeAndCancelsStaleCompletions() {
        let clock = TrayMotionClock()
        var time = 10.0
        clock.now = { time }
        var closed = false
        var lastElapsed = 0.0
        clock.run("surface", duration: 0.2, update: { lastElapsed = $0 }, completion: { closed = true })
        time = 10.1
        clock.tick()
        XCTAssertEqual(lastElapsed, 0.1, accuracy: 0.0001)
        clock.cancelAll()
        clock.run("surface", duration: 0.34, update: { lastElapsed = $0 })
        time = 15 // dropped frames finish once, never replay a queue of old frames
        clock.tick()
        XCTAssertFalse(closed)
        XCTAssertEqual(lastElapsed, 0.34)
        XCTAssertFalse(clock.hasWork)
    }

    @MainActor
    func testDelayedJobsCanBeCancelledBeforeTheyStart() {
        let clock = TrayMotionClock()
        var time = 0.0
        clock.now = { time }
        var calls = 0
        clock.run("item", duration: 0.24, delay: 0.19, update: { _ in calls += 1 })
        time = 0.1
        clock.tick()
        XCTAssertEqual(calls, 1) // initial hidden pose only
        clock.cancelAll()
        time = 1
        clock.tick()
        XCTAssertEqual(calls, 1)
        XCTAssertFalse(clock.hasWork)
    }

    @MainActor
    func testVisibleResizeReversesFromCurrentFrameAndEndsCompact() {
        let (store, controller, clock, setTime) = fixture()
        defer { controller.hide(animated: false); clock.cancelAll() }
        controller.showNearCursor(CGPoint(x: 600, y: 500))
        setTime(1); clock.tick()
        controller.setExpanded(true)
        setTime(1.10); clock.tick()
        let intermediate = controller.presentationFrame
        XCTAssertGreaterThan(intermediate.width, 236)
        XCTAssertLessThan(intermediate.width, 480)
        controller.setExpanded(false)
        XCTAssertEqual(controller.presentationFrame, intermediate)
        setTime(2); clock.tick()
        XCTAssertEqual(controller.presentationSize, CGSize(width: 236, height: 236))
        XCTAssertFalse(controller.renderedIsExpanded)
        XCTAssertFalse(store.isExpanded)
        XCTAssertTrue(controller.isInteractive)
        XCTAssertFalse(clock.hasWork)
    }

    @MainActor
    func testReopeningDuringExitCannotBeClosedByOldAnimation() {
        let (store, controller, clock, setTime) = fixture()
        defer { controller.hide(animated: false); clock.cancelAll() }
        controller.showNearCursor()
        controller.closeAndClear()
        XCTAssertTrue(store.items.isEmpty)
        store.addImage(data: Data(), image: NSImage(size: NSSize(width: 8, height: 8)))
        controller.showNearCursor()
        setTime(5); clock.tick()
        XCTAssertTrue(controller.isVisible)
        XCTAssertTrue(controller.isInteractive)
        XCTAssertEqual(store.items.count, 1)
        XCTAssertFalse(clock.hasWork)
    }

    @MainActor
    func testClosingDuringResizeReleasesAllMotionAndReferences() {
        let (store, controller, clock, setTime) = fixture()
        controller.showNearCursor()
        controller.setExpanded(true)
        controller.closeAndClear()
        setTime(2); clock.tick()
        XCTAssertFalse(controller.isVisible)
        XCTAssertTrue(controller.isInteractive)
        XCTAssertTrue(store.items.isEmpty)
        XCTAssertFalse(clock.hasWork)
    }

    @MainActor
    func testConfirmedShareDoesNotRemoveNewItems() {
        let (store, controller, clock, _) = fixture()
        defer { controller.hide(animated: false); clock.cancelAll() }
        let sharedIDs = Set(store.items.map(\.id))
        let added = store.addImage(data: Data(), image: NSImage(size: NSSize(width: 8, height: 8)))
        controller.completeSharing(ids: sharedIDs)
        XCTAssertEqual(store.items.map(\.id), [added.id])
    }

    @MainActor
    func testNativeSharingFailureDoesNotEmitSuccessOrClearStore() throws {
        let store = TrayStore()
        store.addImage(data: Data(), image: NSImage(size: NSSize(width: 8, height: 8)))
        var succeeded = false
        let session = TraySharingSession(items: store.items) { _ in succeeded = true }
        let service = try XCTUnwrap(NSSharingService(named: .sendViaAirDrop))
        session.sharingService(service, didFailToShareItems: [], error: CocoaError(.userCancelled))
        XCTAssertFalse(succeeded)
        XCTAssertEqual(store.items.count, 1)
    }

    @MainActor
    func testAirDropMailAndMessagesConfirmationsAllStartTheSameExitAnimation() throws {
        // Exercise real service objects, but inject their completion notification.
        // No composer is opened and no message/file is sent to another person.
        let names: [NSSharingService.Name] = [.sendViaAirDrop, .composeEmail, .composeMessage]
        for name in names {
            let (store, controller, clock, setTime) = fixture()
            defer { controller.hide(animated: false); clock.cancelAll() }
            controller.showNearCursor()
            setTime(1); clock.tick()
            XCTAssertFalse(clock.hasWork)

            let session = TraySharingSession(items: store.items) { controller.completeSharing(ids: $0) }
            let service = try XCTUnwrap(NSSharingService(named: name))
            session.sharingService(service, didShareItems: [])

            XCTAssertTrue(clock.hasWork, "Any native service confirmation must start the exit")
            XCTAssertTrue(store.items.isEmpty)
            setTime(2); clock.tick()
            XCTAssertFalse(controller.isVisible)
            XCTAssertFalse(clock.hasWork)
        }
    }

    @MainActor
    func testMoreOptionsRoutesAnArbitraryThirdPartyServiceToTheExitAnimation() throws {
        let (store, controller, clock, setTime) = fixture()
        defer { controller.hide(animated: false); clock.cancelAll() }
        controller.showNearCursor()
        setTime(1); clock.tick()

        let session = TraySharingSession(items: store.items) { controller.completeSharing(ids: $0) }
        let picker = NSSharingServicePicker(items: [NSImage(size: NSSize(width: 8, height: 8))])
        picker.delegate = session
        let service = NSSharingService(title: "Third-party test service",
                                       image: NSImage(size: NSSize(width: 16, height: 16)),
                                       alternateImage: nil, handler: {})
        let delegate = try XCTUnwrap(picker.delegate?.sharingServicePicker?(picker, delegateFor: service))
        XCTAssertTrue(delegate === session)
        delegate.sharingService?(service, didShareItems: [])

        XCTAssertTrue(clock.hasWork)
        XCTAssertTrue(store.items.isEmpty)
        setTime(2); clock.tick()
        XCTAssertFalse(controller.isVisible)
        XCTAssertFalse(clock.hasWork)
    }

    @MainActor
    func testChoosingAServiceDoesNotAnimateBeforeConfirmation() throws {
        let (store, controller, clock, setTime) = fixture()
        defer { controller.hide(animated: false); clock.cancelAll() }
        controller.showNearCursor()
        setTime(1); clock.tick()
        let session = TraySharingSession(items: store.items) { controller.completeSharing(ids: $0) }
        let picker = NSSharingServicePicker(items: [])
        let service = try XCTUnwrap(NSSharingService(named: .composeMessage))

        _ = session.sharingServicePicker(picker, delegateFor: service)
        session.sharingService(service, willShareItems: [])
        XCTAssertFalse(clock.hasWork)
        XCTAssertEqual(store.items.count, 1)
        XCTAssertTrue(controller.isVisible)
        session.sharingService(service, didFailToShareItems: [], error: CocoaError(.userCancelled))
        XCTAssertFalse(clock.hasWork)
        XCTAssertEqual(store.items.count, 1)
    }

    @MainActor
    func testThirdPartyFailureDoesNotAnimateOrDiscardReferences() {
        let (store, controller, clock, setTime) = fixture()
        defer { controller.hide(animated: false); clock.cancelAll() }
        controller.showNearCursor()
        setTime(1); clock.tick()
        let session = TraySharingSession(items: store.items) { controller.completeSharing(ids: $0) }
        let service = NSSharingService(title: "Third-party test service",
                                       image: NSImage(size: NSSize(width: 16, height: 16)),
                                       alternateImage: nil, handler: {})
        session.sharingService(service, didFailToShareItems: [], error: CocoaError(.fileReadNoPermission))
        XCTAssertFalse(clock.hasWork)
        XCTAssertEqual(store.items.count, 1)
        XCTAssertTrue(controller.isVisible)
    }

    @MainActor
    private func fixture() -> (TrayStore, TrayPanelController, TrayMotionClock, (Double) -> Void) {
        let store = TrayStore()
        store.addImage(data: Data(), image: NSImage(size: NSSize(width: 8, height: 8)))
        let clock = TrayMotionClock()
        var time = 0.0
        clock.now = { time }
        let controller = TrayPanelController(store: store, motionClock: clock, reduceMotion: false)
        return (store, controller, clock, { time = $0 })
    }

    @MainActor
    func testFiftyRapidReversalsWithThirtyTwoItemsDoNotLeaveWorkOrAnExpandedHitArea() {
        let (store, controller, clock, setTime) = fixture()
        defer { controller.hide(animated: false); clock.cancelAll() }
        for _ in 1..<32 { store.addImage(data: Data(), image: NSImage(size: NSSize(width: 8, height: 8))) }
        controller.showNearCursor(CGPoint(x: 1_100, y: 600))
        for index in 0..<50 {
            controller.setExpanded(index.isMultiple(of: 2))
            setTime(Double(index + 1) * 0.035)
            clock.tick()
        }
        setTime(10); clock.tick()
        XCTAssertEqual(store.items.count, 32)
        XCTAssertEqual(controller.presentationSize, CGSize(width: 236, height: 236))
        XCTAssertFalse(controller.renderedIsExpanded)
        XCTAssertTrue(controller.isInteractive)
        XCTAssertFalse(clock.hasWork)
    }

    @MainActor
    func testSuccessfulShareFinishesAndNextTrayStartsCompact() {
        let (store, controller, clock, setTime) = fixture()
        controller.showNearCursor()
        controller.setExpanded(true)
        controller.completeSharing(ids: Set(store.items.map(\.id)))
        XCTAssertTrue(store.items.isEmpty)
        setTime(1); clock.tick()
        XCTAssertFalse(controller.isVisible)
        XCTAssertFalse(store.isExpanded)
        XCTAssertFalse(clock.hasWork)
    }

    @MainActor
    func testStaleShareCompletionCannotDismissANewEmptyTray() {
        let (store, controller, clock, setTime) = fixture()
        defer { controller.hide(animated: false); clock.cancelAll() }
        let previousIDs = Set(store.items.map(\.id))
        controller.showNearCursor()
        controller.closeAndClear()
        setTime(1); clock.tick()
        controller.showNearCursor()
        controller.completeSharing(ids: previousIDs)
        setTime(2); clock.tick()
        XCTAssertTrue(controller.isVisible)
        XCTAssertTrue(store.items.isEmpty)
        XCTAssertTrue(controller.isInteractive)
    }

    @MainActor
    func testDraggingTheHeaderInterruptsResizeWithoutLosingContent() {
        let (store, controller, clock, setTime) = fixture()
        defer { controller.hide(animated: false); clock.cancelAll() }
        controller.showNearCursor()
        controller.setExpanded(true)
        setTime(0.1); clock.tick()
        controller.beginWindowDrag()
        let settled = controller.presentationFrame
        setTime(1); clock.tick()
        XCTAssertEqual(controller.presentationFrame, settled)
        XCTAssertEqual(settled.width, 480)
        XCTAssertEqual(store.items.count, 1)
        XCTAssertFalse(clock.hasWork)
    }

    @MainActor
    func testAcceptedFolderIsCommittedBeforeAbsorptionAndProxyIsCancelledOnClose() async throws {
        let (store, controller, clock, setTime) = fixture()
        defer { controller.hide(animated: false); clock.cancelAll() }
        controller.showNearCursor()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("MiniTrayFolder-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        XCTAssertEqual(store.addFileURLs([directory]), 1)
        store.onAcceptedDrop?(TrayIncomingDrop(screenPoint: controller.presentationFrame.origin,
                                              folderImage: NSWorkspace.shared.icon(forFile: directory.path)))
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
        XCTAssertEqual(store.items.count, 2, "Import must not wait for the 190 ms visual delay")
        XCTAssertTrue(controller.hasIncomingProxy)
        setTime(0.18); clock.tick()
        XCTAssertEqual(store.items.count, 2)
        controller.closeAndClear()
        XCTAssertFalse(controller.hasIncomingProxy)
        setTime(1); clock.tick()
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.path))
        XCTAssertFalse(controller.isVisible)
        XCTAssertFalse(clock.hasWork)
    }
}
