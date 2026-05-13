import Carbon.HIToolbox
import Foundation

enum GlobalHotkey {
    case activateGestureMode
    case emergencyExit
}

protocol HotkeyManaging: AnyObject {
    var onHotkey: ((GlobalHotkey) -> Void)? { get set }

    func startListening()
    func stopListening()
}

final class HotkeyManager: HotkeyManaging {
    var onHotkey: ((GlobalHotkey) -> Void)?

    private var eventHandler: EventHandlerRef?
    private var activationHotkey: EventHotKeyRef?
    private var emergencyExitHotkey: EventHotKeyRef?

    deinit {
        stopListening()
    }

    func startListening() {
        guard eventHandler == nil else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            hotkeyEventHandler,
            1,
            &eventType,
            selfPointer,
            &eventHandler
        )

        registerHotkeys()
    }

    func stopListening() {
        if let activationHotkey {
            UnregisterEventHotKey(activationHotkey)
            self.activationHotkey = nil
        }

        if let emergencyExitHotkey {
            UnregisterEventHotKey(emergencyExitHotkey)
            self.emergencyExitHotkey = nil
        }

        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }

    private func registerHotkeys() {
        let signature = HotkeyManager.fourCharCode("GGHK")

        let activationID = EventHotKeyID(signature: signature, id: 1)
        RegisterEventHotKey(
            UInt32(kVK_Space),
            UInt32(controlKey | optionKey | cmdKey),
            activationID,
            GetApplicationEventTarget(),
            0,
            &activationHotkey
        )

        let emergencyExitID = EventHotKeyID(signature: signature, id: 2)
        RegisterEventHotKey(
            UInt32(kVK_Escape),
            UInt32(controlKey | optionKey | cmdKey),
            emergencyExitID,
            GetApplicationEventTarget(),
            0,
            &emergencyExitHotkey
        )
    }

    fileprivate func handleHotkey(id: UInt32) {
        switch id {
        case 1:
            onHotkey?(.activateGestureMode)
        case 2:
            onHotkey?(.emergencyExit)
        default:
            break
        }
    }

    private static func fourCharCode(_ string: String) -> OSType {
        var result: OSType = 0

        for scalar in string.unicodeScalars.prefix(4) {
            result = (result << 8) + OSType(scalar.value)
        }

        return result
    }
}

private let hotkeyEventHandler: EventHandlerUPP = { _, event, userData in
    guard let event,
          let userData else {
        return noErr
    }

    var hotkeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotkeyID
    )

    guard status == noErr else {
        return status
    }

    let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
    manager.handleHotkey(id: hotkeyID.id)

    return noErr
}
