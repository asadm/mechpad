import Foundation
import SwiftUI

final class AppState: ObservableObject {
    private enum Keys {
        static let enabled = "mechpad.enabled"
        static let profileID = "mechpad.profileID"
        static let intensity = "mechpad.intensity"
        static let keyUpSound = "mechpad.keyUpSound"
        static let keyAcoustics = "mechpad.keyAcoustics"
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
            onStateChanged?()
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

    @Published var hasGlobalAccess: Bool = false
    @Published var lastKeyLabel: String = "—"
    @Published var pulseCounter: Int = 0
    @Published var totalClicks: Int = 0

    var onStateChanged: (() -> Void)?

    var selectedProfile: SwitchProfile {
        SwitchLibrary.profile(id: selectedProfileID)
    }

    init() {
        let defaults = UserDefaults.standard
        isEnabled = defaults.object(forKey: Keys.enabled) as? Bool ?? true
        selectedProfileID = defaults.string(forKey: Keys.profileID) ?? SwitchLibrary.all[0].id
        intensity = defaults.object(forKey: Keys.intensity) as? Double ?? 0.85
        playKeyUp = defaults.object(forKey: Keys.keyUpSound) as? Bool ?? true
        useKeyAcoustics = defaults.object(forKey: Keys.keyAcoustics) as? Bool ?? true
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

    func handleKey(keyCode: UInt16, isKeyDown: Bool) {
        guard isEnabled else { return }
        if !isKeyDown && !playKeyUp { return }

        let kind = KeyKind.from(keyCode: keyCode)
        let synth = selectedProfile.synthesize(
            keyKind: kind,
            isKeyDown: isKeyDown,
            useKeyAcoustics: useKeyAcoustics
        )
        engine.playKeyEvent(
            primary: synth.primary,
            secondary: synth.secondary,
            masterIntensity: Float(intensity)
        )

        if isKeyDown {
            let label = KeyKind.displayName(for: keyCode)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.lastKeyLabel = label
                self.pulseCounter += 1
                self.totalClicks += 1
            }
        }
    }

    /// Auditions a specific profile with a simulated downstroke + upstroke click.
    func audition(profile: SwitchProfile, keyKind: KeyKind = .alpha) {
        let down = profile.synthesize(keyKind: keyKind, isKeyDown: true, useKeyAcoustics: useKeyAcoustics)
        engine.playKeyEvent(primary: down.primary, secondary: down.secondary, masterIntensity: Float(intensity))

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.lastKeyLabel = keyKind == .spacebar ? "Space" : "Test"
            self.pulseCounter += 1
            self.totalClicks += 1
        }

        if playKeyUp {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.085) { [weak self] in
                guard let self else { return }
                let up = profile.synthesize(keyKind: keyKind, isKeyDown: false, useKeyAcoustics: self.useKeyAcoustics)
                self.engine.playKeyEvent(primary: up.primary, secondary: nil, masterIntensity: Float(self.intensity))
            }
        }
    }
}
