import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate {
    private let state = AppState()
    private var statusItem: NSStatusItem?
    private var mainWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu bar only: LSUIElement in Info.plist keeps MechPad out of the Dock.
        NSApp.mainMenu = makeMainMenu()
        setupStatusItem()
        state.onStateChanged = { [weak self] in
            self?.updateStatusIcon()
        }
        // Once set up, start silently in the menu bar (e.g. at login); otherwise show setup.
        if !AXIsProcessTrusted() || !state.engine.isAvailable || !state.setupDone {
            showMainWindow()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showMainWindow()
        }
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        state.shutdown()
    }

    // MARK: - Window

    @objc private func showMainWindow() {
        if let window = mainWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let contentView = ContentView(state: state, onClose: { [weak self] in
            self?.mainWindow?.performClose(nil)
        })
        let window = NSWindow(contentViewController: NSHostingController(rootView: contentView))
        window.title = String(localized: "MechPad Settings")
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 520, height: 680))
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self

        mainWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Without a Dock icon the main menu is never shown, but it still routes ⌘C, ⌘V, ⌘W and friends.
    private func makeMainMenu() -> NSMenu {
        let main = NSMenu()

        let appMenu = NSMenu()
        let settings = NSMenuItem(title: "Settings…", action: #selector(showMainWindow), keyEquivalent: ",")
        settings.target = self
        appMenu.addItem(settings)
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: "Quit MechPad", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))
        editMenu.addItem(NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z"))
        editMenu.addItem(.separator())
        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))

        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(NSMenuItem(title: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))

        for (title, submenu) in [("MechPad", appMenu), ("Edit", editMenu), ("Window", windowMenu)] {
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            item.submenu = submenu
            main.addItem(item)
        }
        return main
    }

    // MARK: - Status item

    private let statusMenu = NSMenu()

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusMenu.delegate = self // items are built fresh each time the menu opens
        // No permanent item.menu: it would open on right-click too, and right-click pauses instead.
        item.button?.target = self
        item.button?.action = #selector(statusItemClicked(_:))
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem = item
        updateStatusIcon()
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        let isRightClick = event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true
        if isRightClick && (state.status == .active || state.status == .paused) {
            state.isEnabled.toggle()
            return
        }
        statusItem?.menu = statusMenu
        sender.performClick(nil)
    }

    func menuDidClose(_ menu: NSMenu) {
        if menu === statusMenu {
            statusItem?.menu = nil
        }
    }

    private func updateStatusIcon() {
        guard let button = statusItem?.button else { return }
        switch state.status {
        case .needsAccess, .noTrackpad:
            button.image = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: String(localized: "MechPad needs attention"))
            button.appearsDisabled = false
        case .active, .paused:
            button.image = Self.keycapGlyph
            button.appearsDisabled = state.status == .paused
        }
        var tip = String(localized: "MechPad: \(state.statusTitle)")
        if state.status == .active || state.status == .paused {
            tip += "\n" + String(localized: "Right-click to pause or resume")
        }
        button.toolTip = tip
    }

    /// Template glyph matching the app icon: a keycap with haptic ripples on both sides.
    private static let keycapGlyph: NSImage = {
        let image = NSImage(size: NSSize(width: 22, height: 16), flipped: false) { _ in
            let keycap = NSBezierPath(roundedRect: NSRect(x: 6.5, y: 2.5, width: 9, height: 11), xRadius: 2.5, yRadius: 2.5)
            keycap.lineWidth = 1.5
            keycap.stroke()
            for (x, start, end) in [(11.0, 140.0, 220.0), (11.0, -40.0, 40.0)] {
                let ripple = NSBezierPath()
                ripple.appendArc(withCenter: NSPoint(x: x, y: 8), radius: 8.5, startAngle: start, endAngle: end)
                ripple.lineWidth = 1.5
                ripple.lineCapStyle = .round
                ripple.stroke()
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "MechPad"
        return image
    }()

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let header = NSMenuItem(title: String(localized: "MechPad: \(state.statusTitle)"), action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        switch state.status {
        case .needsAccess:
            menu.addItem(item("Grant Accessibility Access…", #selector(grantAccess), symbol: "hand.raised"))
        case .active:
            menu.addItem(item("Pause Clicks", #selector(toggleEnabled), symbol: "pause.circle"))
        case .paused:
            menu.addItem(item("Resume Clicks", #selector(toggleEnabled), symbol: "play.circle"))
        case .noTrackpad:
            break
        }

        menu.addItem(.separator())
        menu.addItem(intensityItem())

        let profileMenu = NSMenu()
        for profile in SwitchLibrary.all {
            let entry = item("\(profile.name)", #selector(selectProfile(_:)))
            entry.representedObject = profile.id
            entry.state = profile.id == state.selectedProfileID ? .on : .off
            entry.image = Self.stemIcon(NSColor(profile.stemColor))
            profileMenu.addItem(entry)
        }
        let profileItem = NSMenuItem(title: String(localized: "Switch: \(state.selectedProfile.name)"), action: nil, keyEquivalent: "")
        profileItem.submenu = profileMenu
        profileItem.image = Self.stemIcon(NSColor(state.selectedProfile.stemColor))
        menu.addItem(profileItem)

        menu.addItem(.separator())
        let login = item("Launch at Login", #selector(toggleLaunchAtLogin), symbol: "power")
        login.state = state.launchAtLogin ? .on : .off
        menu.addItem(login)
        let settings = item("Settings…", #selector(showMainWindow), symbol: "gearshape")
        settings.keyEquivalent = ","
        menu.addItem(settings)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: String(localized: "Quit MechPad"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.image = NSImage(systemSymbolName: "xmark.rectangle", accessibilityDescription: nil)
        menu.addItem(quit)

        // macOS 27 hides menu item images by default; ask for ours to stay visible.
        if #available(macOS 27, *) {
            for entry in menu.items + profileMenu.items where entry.image != nil {
                entry.preferredImageVisibility = .visible
            }
        }
    }

    private func item(_ title: String.LocalizationValue, _ action: Selector, symbol: String? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: String(localized: title), action: action, keyEquivalent: "")
        item.target = self
        if let symbol {
            item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        }
        return item
    }

    /// Menu-sized version of the settings window's cross-stem icon, in the switch's own color.
    private static func stemIcon(_ color: NSColor) -> NSImage {
        NSImage(size: NSSize(width: 16, height: 16), flipped: false) { rect in
            let frame = NSBezierPath(roundedRect: rect.insetBy(dx: 1.5, dy: 1.5), xRadius: 3, yRadius: 3)
            frame.lineWidth = 1.5
            color.withAlphaComponent(0.6).setStroke()
            frame.stroke()
            color.setFill()
            let c = NSPoint(x: rect.midX, y: rect.midY)
            NSBezierPath(roundedRect: NSRect(x: c.x - 2, y: c.y - 5, width: 4, height: 10), xRadius: 1, yRadius: 1).fill()
            NSBezierPath(roundedRect: NSRect(x: c.x - 5, y: c.y - 2, width: 10, height: 4), xRadius: 1, yRadius: 1).fill()
            return true
        }
    }

    private func intensityItem() -> NSMenuItem {
        let label = NSTextField(labelWithString: String(localized: "Intensity"))
        label.font = .menuFont(ofSize: 0)
        label.textColor = .secondaryLabelColor
        let slider = NSSlider(value: state.intensity, minValue: 0.15, maxValue: 1.0,
                              target: self, action: #selector(intensityChanged(_:)))
        slider.isContinuous = true
        slider.controlSize = .small
        slider.setAccessibilityLabel(String(localized: "Intensity"))

        let stack = NSStackView(views: [label, slider])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        stack.edgeInsets = NSEdgeInsets(top: 4, left: 14, bottom: 6, right: 14)
        stack.frame = NSRect(x: 0, y: 0, width: 240, height: 48)
        slider.widthAnchor.constraint(equalToConstant: 212).isActive = true

        let item = NSMenuItem()
        item.view = stack
        return item
    }

    @objc private func intensityChanged(_ sender: NSSlider) {
        state.intensity = sender.doubleValue
    }

    @objc private func grantAccess() {
        state.monitor.requestAccessibilityPermission()
    }

    @objc private func toggleEnabled() {
        state.isEnabled.toggle()
    }

    @objc private func toggleLaunchAtLogin() {
        state.setLaunchAtLogin(!state.launchAtLogin)
    }

    @objc private func selectProfile(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        state.selectedProfileID = id
        state.audition(profile: SwitchLibrary.profile(id: id))
    }
}

// Entry point
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
