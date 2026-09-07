import Carbon.HIToolbox
import Foundation

@MainActor
final class GlobalShortcutMonitor {
    enum RegistrationResult: Equatable {
        case registered
        case conflict
        case failed(OSStatus)
    }

    private static let signature: OSType = 0x424E4A41 // BNJA
    private static let identifier: UInt32 = 1

    private var eventHandler: EventHandlerRef?
    private var hotKey: EventHotKeyRef?
    private let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
        installHandler()
    }

    @discardableResult
    func register(_ preset: GlobalShortcutPreset) -> RegistrationResult {
        unregister()
        let definition = Self.definition(for: preset)
        var reference: EventHotKeyRef?
        let identifier = EventHotKeyID(signature: Self.signature, id: Self.identifier)
        let status = RegisterEventHotKey(
            definition.keyCode,
            definition.modifiers,
            identifier,
            GetApplicationEventTarget(),
            0,
            &reference
        )

        guard status == noErr else {
            return status == eventHotKeyExistsErr ? .conflict : .failed(status)
        }
        hotKey = reference
        return .registered
    }

    func unregister() {
        if let hotKey {
            UnregisterEventHotKey(hotKey)
        }
        hotKey = nil
    }

    private func installHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            globalShortcutEventHandler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
    }

    fileprivate func handleHotKeyEvent(_ event: EventRef?) -> OSStatus {
        guard let event else { return OSStatus(eventNotHandledErr) }
        var identifier = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &identifier
        )
        guard status == noErr,
              identifier.signature == Self.signature,
              identifier.id == Self.identifier else {
            return OSStatus(eventNotHandledErr)
        }
        action()
        return OSStatus(noErr)
    }

    static func definition(for preset: GlobalShortcutPreset) -> (keyCode: UInt32, modifiers: UInt32) {
        switch preset {
        case .controlOptionSpace:
            return (UInt32(kVK_Space), UInt32(controlKey | optionKey))
        case .optionCommandSpace:
            return (UInt32(kVK_Space), UInt32(optionKey | cmdKey))
        case .optionShiftSpace:
            return (UInt32(kVK_Space), UInt32(optionKey | shiftKey))
        case .commandShiftB:
            return (UInt32(kVK_ANSI_B), UInt32(cmdKey | shiftKey))
        }
    }

    deinit {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let eventHandler { RemoveEventHandler(eventHandler) }
    }
}

private let globalShortcutEventHandler: EventHandlerUPP = { _, event, userData in
    guard let userData else { return OSStatus(eventNotHandledErr) }
    let monitor = Unmanaged<GlobalShortcutMonitor>.fromOpaque(userData).takeUnretainedValue()
    return MainActor.assumeIsolated {
        monitor.handleHotKeyEvent(event)
    }
}
