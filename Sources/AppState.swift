import AppKit
import Foundation
import ServiceManagement
import SwiftUI

/// What the user should know right now, shown the same way in the window and the menu bar.
enum AppStatus {
    case active, paused, needsAccess, noTrackpad
}

final class AppState: ObservableObject {
    private enum Keys {
        static let enabled = "mechpad.enabled"
        static let profileID = "mechpad.profileID"
        static let intensity = "mechpad.intensity"
        static let keyUpSound = "mechpad.keyUpSound"
        static let keyAcoustics = "mechpad.keyAcoustics"
        static let setupDone = "mechpad.setupDone"
        static let builtInOnly = "mechpad.builtInOnly"
    }

    let engine = HapticEngine()
    let monitor = KeyboardMonitor()

    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Keys.enabled)
            onStateChanged?()
        }
    }

    @Published var selectedProfileID: String {
        didSet {
            UserDefaults.standard.set(selectedProfileID, forKey: Keys.profileID)
        }
    }

    @Published var intensity: Double {
        didSet {
            UserDefaults.standard.set(intensity, forKey: Keys.intensity)
        }
    }

    @Published var playKeyUp: Bool {
        didSet {
            UserDefaults.standard.set(playKeyUp, forKey: Keys.keyUpSound)
        }
    }

    @Published var useKeyAcoustics: Bool {
        didSet {
            UserDefaults.standard.set(useKeyAcoustics, forKey: Keys.keyAcoustics)
        }
    }

    @Published var builtInOnly: Bool {
        didSet {
            UserDefaults.standard.set(builtInOnly, forKey: Keys.builtInOnly)
            monitor.builtInOnly = builtInOnly
        }
    }

    /// The user has seen the "you're all set" step and dismissed it.
    @Published var setupDone: Bool {
        didSet {
            UserDefaults.standard.set(setupDone, forKey: Keys.setupDone)
        }
    }

    @Published var hasGlobalAccess: Bool = false {
        didSet { onStateChanged?() }
    }

    @Published private(set) var launchAtLogin = SMAppService.mainApp.status == .enabled

    /// Called when anything the menu bar icon reflects has changed.
    var onStateChanged: (() -> Void)?

    var selectedProfile: SwitchProfile {
        SwitchLibrary.profile(id: selectedProfileID)
    }

    var status: AppStatus {
        if !engine.isAvailable { return .noTrackpad }
        if !hasGlobalAccess { return .needsAccess }
        return isEnabled ? .active : .paused
    }

    var statusTitle: String {
        switch status {
        case .active: return String(localized: "Active · \(selectedProfile.name)")
        case .paused: return String(localized: "Paused")
        case .needsAccess: return String(localized: "Needs Accessibility access")
        case .noTrackpad: return String(localized: "No Force Touch trackpad found")
        }
    }

    init() {
        let defaults = UserDefaults.standard
        isEnabled = defaults.object(forKey: Keys.enabled) as? Bool ?? true
        selectedProfileID = defaults.string(forKey: Keys.profileID) ?? SwitchLibrary.all[0].id
        intensity = defaults.object(forKey: Keys.intensity) as? Double ?? 0.85
        playKeyUp = defaults.object(forKey: Keys.keyUpSound) as? Bool ?? true
        useKeyAcoustics = defaults.object(forKey: Keys.keyAcoustics) as? Bool ?? true
        setupDone = defaults.bool(forKey: Keys.setupDone)
        builtInOnly = defaults.object(forKey: Keys.builtInOnly) as? Bool ?? true
        monitor.builtInOnly = builtInOnly

        monitor.onPermissionChanged = { [weak self] granted in
            DispatchQueue.main.async {
                self?.hasGlobalAccess = granted
            }
        }

        monitor.onKeyEvent = { [weak self] keyCode, isKeyDown in
            self?.handleKey(keyCode: keyCode, isKeyDown: isKeyDown)
        }

        monitor.start()
    }

    func shutdown() {
        monitor.stop()
        engine.close()
    }

    func setLaunchAtLogin(_ on: Bool) {
        let service = SMAppService.mainApp
        do {
            if on {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            NSApp.activate(ignoringOtherApps: true)
            NSAlert(error: error).runModal()
        }
        launchAtLogin = service.status == .enabled
    }

    func handleKey(keyCode: UInt16, isKeyDown: Bool) {
        guard isEnabled else { return }
        if !isKeyDown && !playKeyUp { return }

        let synth = selectedProfile.synthesize(
            keyKind: KeyKind.from(keyCode: keyCode),
            isKeyDown: isKeyDown,
            useKeyAcoustics: useKeyAcoustics
        )
        engine.playKeyEvent(
            primary: synth.primary,
            secondary: synth.secondary,
            masterIntensity: Float(intensity)
        )
    }

    /// Auditions a specific profile with a simulated downstroke + upstroke click.
    func audition(profile: SwitchProfile, keyKind: KeyKind = .alpha) {
        let down = profile.synthesize(keyKind: keyKind, isKeyDown: true, useKeyAcoustics: useKeyAcoustics)
        engine.playKeyEvent(primary: down.primary, secondary: down.secondary, masterIntensity: Float(intensity))

        if playKeyUp {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.085) { [weak self] in
                guard let self else { return }
                let up = profile.synthesize(keyKind: keyKind, isKeyDown: false, useKeyAcoustics: self.useKeyAcoustics)
                self.engine.playKeyEvent(primary: up.primary, secondary: nil, masterIntensity: Float(self.intensity))
            }
        }
    }
}
