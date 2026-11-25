import AppKit
import ApplicationServices
import Carbon

/// Monitors global keyboard events via a listen-only `CGEventTap` when Accessibility
/// permission is granted, and falls back to an in-app `NSEvent` local monitor so users
/// can audition switch profiles immediately inside MechPad even before granting access.
final class KeyboardMonitor {
    typealias KeyHandler = (_ keyCode: UInt16, _ isKeyDown: Bool) -> Void

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var localMonitor: Any?
    private var permissionTimer: Timer?
    private var lastModifierFlags: CGEventFlags = []
    private var builtInBySender: [UInt64: Bool] = [:]

    var onKeyEvent: KeyHandler?
    /// Click only for the Mac's own keyboard, not for external ones.
    var builtInOnly = false
    var onPermissionChanged: ((Bool) -> Void)?

    private(set) var hasGlobalAccess: Bool = false

    func start() {
        refreshPermissionAndStartTap()
        installLocalFallbackMonitor()

        // Poll lightly while waiting for Accessibility permission so granting access
        // in System Settings activates global typing automatically.
        permissionTimer?.invalidate()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            let trusted = AXIsProcessTrusted()
            if trusted != self.hasGlobalAccess {
                self.refreshPermissionAndStartTap()
            }
        }
    }

    func stop() {
        permissionTimer?.invalidate()
        permissionTimer = nil
        stopGlobalTap()
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
    }

    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)

        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private func refreshPermissionAndStartTap() {
        let trusted = AXIsProcessTrusted()
        if trusted {
            if eventTap == nil {
                startGlobalTap()
            }
            hasGlobalAccess = (eventTap != nil)
        } else {
            stopGlobalTap()
            hasGlobalAccess = false
        }
        onPermissionChanged?(hasGlobalAccess)
    }

    private func installLocalFallbackMonitor() {
        guard localMonitor == nil else { return }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            guard let self else { return event }
            // Avoid double-triggering when the global CGEventTap is already active.
            if self.eventTap != nil { return event }
            if event.type == .keyDown && event.isARepeat { return event }
            let isDown = (event.type == .keyDown)
            self.onKeyEvent?(event.keyCode, isDown)
            return event
        }
    }

    private func startGlobalTap() {
        stopGlobalTap()

        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue)

        let refcon = Unmanaged.passUnretained(self).toOpaque()

        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else { return Unmanaged.passUnretained(event) }
            let monitor = Unmanaged<KeyboardMonitor>.fromOpaque(userInfo).takeUnretainedValue()

            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = monitor.eventTap {
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
                return Unmanaged.passUnretained(event)
            }

            monitor.handleCGEvent(type: type, event: event)
            return Unmanaged.passUnretained(event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: refcon
        ) else {
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        }
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func stopGlobalTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            runLoopSource = nil
        }
        eventTap = nil
    }

    private func handleCGEvent(type: CGEventType, event: CGEvent) {
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        // Keystrokes posted by other apps (e.g. RuSwitcher retyping a word) carry their event source's
        // user data; hardware keystrokes have 0. Clicking on them causes a machine-gun burst.
        let isSynthetic = event.getIntegerValueField(.eventSourceUserData) != 0
        let ignored = isSynthetic || (builtInOnly && !isFromBuiltInKeyboard(event))

        switch type {
        case .keyDown:
            if ignored { return }
            if event.getIntegerValueField(.keyboardEventAutorepeat) != 0 { return }
            onKeyEvent?(keyCode, true)

        case .keyUp:
            if ignored { return }
            onKeyEvent?(keyCode, false)

        case .flagsChanged:
            let flags = event.flags
            let relevantMask: CGEventFlags = [.maskShift, .maskControl, .maskAlternate, .maskCommand, .maskAlphaShift]
            let prev = lastModifierFlags.intersection(relevantMask)
            let curr = flags.intersection(relevantMask)
            lastModifierFlags = flags // track ignored changes too, so the next real one compares correctly
            if curr != prev && !ignored {
                let isDown = curr.rawValue > prev.rawValue
                onKeyEvent?(keyCode, isDown)
            }

        default:
            break
        }
    }

    /// Looks up the HID service that sent the event and checks its "Built-In" property.
    /// Field 87 (sender's IORegistry ID) is undocumented; if it is missing we fail open and click.
    private func isFromBuiltInKeyboard(_ event: CGEvent) -> Bool {
        guard let field = CGEventField(rawValue: 87) else { return true }
        let senderID = UInt64(bitPattern: event.getIntegerValueField(field))
        if senderID == 0 { return true }
        if let cached = builtInBySender[senderID] { return cached }

        var builtIn = false
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IORegistryEntryIDMatching(senderID))
        if service != 0 {
            let value = IORegistryEntrySearchCFProperty(
                service, kIOServicePlane, "Built-In" as CFString, kCFAllocatorDefault,
                IOOptionBits(kIORegistryIterateRecursively | kIORegistryIterateParents)
            )
            builtIn = (value as? Bool) ?? false
            IOObjectRelease(service)
        }
        builtInBySender[senderID] = builtIn
        return builtIn
    }
}
