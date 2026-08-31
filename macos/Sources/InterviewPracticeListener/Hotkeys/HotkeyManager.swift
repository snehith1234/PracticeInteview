import Foundation
import AppKit
import Carbon.HIToolbox

/// Registers system-wide global hotkeys using the Carbon Hot Key API (the
/// standard approach for global shortcuts that fire even when another app has
/// focus). No accessibility permission is needed for RegisterEventHotKey.
///
/// Defaults:
///   Cmd + Shift + Space  -> toggle show/hide
///   Cmd + Shift + L      -> start/stop listening
///   Cmd + Shift + C      -> toggle compact/expanded
final class HotkeyManager {

    static let shared = HotkeyManager()

    var onToggleVisibility: (() -> Void)?
    var onToggleListening: (() -> Void)?
    var onToggleCompact: (() -> Void)?

    private var hotKeyRefs: [EventHotKeyRef?] = []
    private var eventHandler: EventHandlerRef?

    private enum HotkeyID: UInt32 {
        case toggleVisibility = 1
        case toggleListening = 2
        case toggleCompact = 3
    }

    func register() {
        installHandler()
        let cmdShift = UInt32(cmdKey | shiftKey)
        registerHotKey(id: .toggleVisibility, keyCode: UInt32(kVK_Space), modifiers: cmdShift)
        registerHotKey(id: .toggleListening, keyCode: UInt32(kVK_ANSI_L), modifiers: cmdShift)
        registerHotKey(id: .toggleCompact, keyCode: UInt32(kVK_ANSI_C), modifiers: cmdShift)
    }

    func unregister() {
        for ref in hotKeyRefs { if let ref { UnregisterEventHotKey(ref) } }
        hotKeyRefs.removeAll()
        if let handler = eventHandler { RemoveEventHandler(handler); eventHandler = nil }
    }

    private func installHandler() {
        guard eventHandler == nil else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: OSType(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData -> OSStatus in
            guard let event, let userData else { return noErr }
            var hkID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &hkID)
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async { manager.handle(id: hkID.id) }
            return noErr
        }, 1, &eventType, selfPtr, &eventHandler)
    }

    private func registerHotKey(id: HotkeyID, keyCode: UInt32, modifiers: UInt32) {
        var ref: EventHotKeyRef?
        let hkID = EventHotKeyID(signature: OSType(0x49504C48), id: id.rawValue) // 'IPLH'
        let status = RegisterEventHotKey(keyCode, modifiers, hkID,
                                         GetApplicationEventTarget(), 0, &ref)
        if status == noErr { hotKeyRefs.append(ref) }
    }

    private func handle(id: UInt32) {
        switch HotkeyID(rawValue: id) {
        case .toggleVisibility: onToggleVisibility?()
        case .toggleListening: onToggleListening?()
        case .toggleCompact: onToggleCompact?()
        case .none: break
        }
    }
}
