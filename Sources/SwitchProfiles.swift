import SwiftUI

/// Acoustic category of key pressed, used to shape stabilizer / keycap mass resonance.
enum KeyKind: String {
    case alpha = "Key"
    case spacebar = "Space"
    case enter = "Return"
    case backspace = "Delete"
    case modifier = "Modifier"

    var pitchMultiplier: Double {
        switch self {
        case .alpha:     return 1.00
        case .spacebar:  return 0.72
        case .enter:     return 0.80
        case .backspace: return 0.85
        case .modifier:  return 0.90
        }
    }

    var levelMultiplier: Float {
        switch self {
        case .alpha:     return 1.00
        case .spacebar:  return 1.15
        case .enter:     return 1.10
        case .backspace: return 1.06
        case .modifier:  return 0.92
        }
    }

    var durationMultiplier: Double {
        switch self {
        case .alpha:     return 1.00
        case .spacebar:  return 1.32
        case .enter:     return 1.18
        case .backspace: return 1.12
        case .modifier:  return 1.08
        }
    }

    static func from(keyCode: UInt16) -> KeyKind {
        switch keyCode {
        case 49: return .spacebar
        case 36, 76: return .enter
        case 51, 117: return .backspace
        case 48, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63: return .modifier
        default: return .alpha
        }
    }

    /// Built from the key code only: MechPad never reads which characters are typed.
    static func displayName(for keyCode: UInt16) -> String {
        switch keyCode {
        case 49: return "Space"
        case 36, 76: return "Return"
        case 51: return "Delete"
        case 117: return "Fwd Del"
        case 48: return "Tab"
        case 53: return "Esc"
        case 56, 60: return "Shift"
        case 57: return "Caps"
        case 55, 54: return "Cmd"
        case 58, 61: return "Opt"
        case 59, 62: return "Ctrl"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        default: return "Key"
        }
    }
}

struct SwitchTraits {
    let thock: Double     // 0...1
    let clack: Double     // 0...1
    let tactility: Double // 0...1
}

struct SwitchProfile: Identifiable, Equatable {
    let id: String
    let name: String
    let category: String
    let tagline: String
    let stemHex: UInt32
    let traits: SwitchTraits

    // Downstroke synthesis parameters
    let downBaseGaussianAmp: Double
    let downBaseDurationMS: Double
    let downTones: [HapticTone]
    let downLevel: Float

    // Optional second stage on downstroke (e.g. click-jacket bottom-out or buckling spring ping)
    let downStage2DelayMS: Double?
    let downStage2Tones: [HapticTone]
    let downStage2Level: Float

    // Upstroke synthesis parameters
    let upBaseGaussianAmp: Double
    let upBaseDurationMS: Double
    let upTones: [HapticTone]
    let upLevel: Float

    static func == (lhs: SwitchProfile, rhs: SwitchProfile) -> Bool {
        lhs.id == rhs.id
    }

    var stemColor: Color {
        Color(
            red: Double((stemHex >> 16) & 0xFF) / 255.0,
            green: Double((stemHex >> 8) & 0xFF) / 255.0,
            blue: Double(stemHex & 0xFF) / 255.0
        )
    }

    /// Generates organic, key-aware haptic bursts for a single key-down or key-up event.
    func synthesize(keyKind: KeyKind, isKeyDown: Bool, useKeyAcoustics: Bool) -> (primary: HapticBurst, secondary: (HapticBurst, Double)?) {
        let pitchMult = (useKeyAcoustics ? keyKind.pitchMultiplier : 1.0) * Double.random(in: 0.96...1.04)
        let levelMult = (useKeyAcoustics ? keyKind.levelMultiplier : 1.0) * Float.random(in: 0.95...1.05)
        let durMult = useKeyAcoustics ? keyKind.durationMultiplier : 1.0

        if isKeyDown {
            let scaledTones = downTones.map {
                HapticTone(
                    hz: $0.hz * pitchMult,
                    amp: $0.amp,
                    durationMS: $0.durationMS * durMult,
                    delayMS: $0.delayMS
                )
            }
            let primary = HapticBurst(
                baseGaussianAmp: downBaseGaussianAmp,
                baseDurationMS: downBaseDurationMS * durMult,
                tones: scaledTones,
                level: min(1.0, downLevel * levelMult)
            )

            var secondary: (HapticBurst, Double)? = nil
            if let delay = downStage2DelayMS, !downStage2Tones.isEmpty {
                let s2Tones = downStage2Tones.map {
                    HapticTone(
                        hz: $0.hz * pitchMult,
                        amp: $0.amp,
                        durationMS: $0.durationMS * durMult,
                        delayMS: $0.delayMS
                    )
                }
                let s2Burst = HapticBurst(
                    baseGaussianAmp: 0.0,
                    baseDurationMS: 4.0,
                    tones: s2Tones,
                    level: min(1.0, downStage2Level * levelMult)
                )
                secondary = (s2Burst, delay)
            }

            return (primary, secondary)
        } else {
            let scaledUp = upTones.map {
                HapticTone(
                    hz: $0.hz * pitchMult,
                    amp: $0.amp,
                    durationMS: $0.durationMS * durMult,
                    delayMS: $0.delayMS
                )
            }
            let primary = HapticBurst(
                baseGaussianAmp: upBaseGaussianAmp,
                baseDurationMS: upBaseDurationMS * durMult,
                tones: scaledUp,
                level: min(1.0, upLevel * levelMult)
            )
            return (primary, nil)
        }
    }
}

enum SwitchLibrary {
    static let all: [SwitchProfile] = [
        // 1. Cherry MX Blue — iconic sharp click-jacket snap + crisp clack (calibrated to trackpad highs)
        SwitchProfile(
            id: "cherry-mx-blue",
            name: "Cherry MX Blue",
            category: "Clicky",
            tagline: "Bright click-jacket snap with sharp, crisp clack",
            stemHex: 0x0A84FF,
            traits: SwitchTraits(thock: 0.35, clack: 0.95, tactility: 0.90),
            downBaseGaussianAmp: 0.16,
            downBaseDurationMS: 3.0,
            downTones: [
                HapticTone(hz: 2680, amp: 0.52, durationMS: 5.5),
                HapticTone(hz: 3850, amp: 0.36, durationMS: 4.5),
                HapticTone(hz: 1240, amp: 0.12, durationMS: 6.5),
            ],
            downLevel: 0.84,
            downStage2DelayMS: 5.0,
            downStage2Tones: [
                HapticTone(hz: 560, amp: 0.50, durationMS: 6.5),
                HapticTone(hz: 1480, amp: 0.50, durationMS: 5.0),
            ],
            downStage2Level: 0.48,
            upBaseGaussianAmp: 0.06,
            upBaseDurationMS: 2.5,
            upTones: [
                HapticTone(hz: 3180, amp: 0.62, durationMS: 4.0),
                HapticTone(hz: 1680, amp: 0.38, durationMS: 4.5),
            ],
            upLevel: 0.42
        ),

        // 2. Cherry MX Brown — distinct dry tactile notch + balanced mid-range clack
        SwitchProfile(
            id: "cherry-mx-brown",
            name: "Cherry MX Brown",
            category: "Tactile",
            tagline: "Gentle tactile notch with balanced, muted bottom-out",
            stemHex: 0x8B5A2B,
            traits: SwitchTraits(thock: 0.55, clack: 0.50, tactility: 0.60),
            downBaseGaussianAmp: 0.14,
            downBaseDurationMS: 4.5,
            downTones: [
                HapticTone(hz: 1220, amp: 0.46, durationMS: 6.0),
                HapticTone(hz: 1680, amp: 0.28, durationMS: 4.5),
                HapticTone(hz: 480, amp: 0.26, durationMS: 8.5),
            ],
            downLevel: 0.84,
            downStage2DelayMS: 4.5,
            downStage2Tones: [
                HapticTone(hz: 680, amp: 0.60, durationMS: 6.5),
                HapticTone(hz: 1120, amp: 0.40, durationMS: 4.5),
            ],
            downStage2Level: 0.40,
            upBaseGaussianAmp: 0.05,
            upBaseDurationMS: 3.0,
            upTones: [
                HapticTone(hz: 1240, amp: 0.58, durationMS: 4.0),
                HapticTone(hz: 620, amp: 0.42, durationMS: 4.5),
            ],
            upLevel: 0.34
        ),

        // 3. Cherry MX Red — smooth, quieter linear travel with soft low-mid bottom-out
        SwitchProfile(
            id: "cherry-mx-red",
            name: "Cherry MX Red",
            category: "Linear",
            tagline: "Smooth linear feel with clean, light bottom-out",
            stemHex: 0xE03131,
            traits: SwitchTraits(thock: 0.50, clack: 0.45, tactility: 0.18),
            downBaseGaussianAmp: 0.12,
            downBaseDurationMS: 5.5,
            downTones: [
                HapticTone(hz: 520, amp: 0.54, durationMS: 9.0),
                HapticTone(hz: 780, amp: 0.36, durationMS: 6.5),
                HapticTone(hz: 1080, amp: 0.10, durationMS: 4.0),
            ],
            downLevel: 0.62,
            downStage2DelayMS: nil,
            downStage2Tones: [],
            downStage2Level: 0.0,
            upBaseGaussianAmp: 0.04,
            upBaseDurationMS: 3.0,
            upTones: [
                HapticTone(hz: 740, amp: 0.65, durationMS: 4.0),
                HapticTone(hz: 410, amp: 0.35, durationMS: 4.5),
            ],
            upLevel: 0.26
        ),

        // 4. Holy Panda — punchy, hollow woody low-mid "pop" + warm thock
        SwitchProfile(
            id: "holy-panda",
            name: "Holy Panda",
            category: "Tactile · Thock",
            tagline: "Pronounced rounded bump with signature woody pop",
            stemHex: 0xF4A261,
            traits: SwitchTraits(thock: 0.86, clack: 0.65, tactility: 0.94),
            downBaseGaussianAmp: 0.18,
            downBaseDurationMS: 6.0,
            downTones: [
                HapticTone(hz: 660, amp: 0.48, durationMS: 10.0),
                HapticTone(hz: 920, amp: 0.32, durationMS: 7.0),
                HapticTone(hz: 310, amp: 0.20, durationMS: 12.0),
            ],
            downLevel: 0.98,
            downStage2DelayMS: 5.5,
            downStage2Tones: [
                HapticTone(hz: 520, amp: 0.62, durationMS: 9.0),
                HapticTone(hz: 780, amp: 0.38, durationMS: 6.0),
            ],
            downStage2Level: 0.56,
            upBaseGaussianAmp: 0.10,
            upBaseDurationMS: 4.0,
            upTones: [
                HapticTone(hz: 820, amp: 0.58, durationMS: 5.5),
                HapticTone(hz: 440, amp: 0.42, durationMS: 6.5),
            ],
            upLevel: 0.44
        ),

        // 5. Topre 45g — deepest, muted rubber-dome electrostatic thock
        SwitchProfile(
            id: "topre-45g",
            name: "Topre 45g",
            category: "Electrostatic",
            tagline: "Iconic deep, muted HHKB rubber-dome thock",
            stemHex: 0x6C5CE7,
            traits: SwitchTraits(thock: 0.98, clack: 0.24, tactility: 0.72),
            downBaseGaussianAmp: 0.26,
            downBaseDurationMS: 9.5,
            downTones: [
                HapticTone(hz: 150, amp: 0.52, durationMS: 16.5),
                HapticTone(hz: 265, amp: 0.38, durationMS: 13.5),
                HapticTone(hz: 390, amp: 0.10, durationMS: 8.0),
            ],
            downLevel: 0.98,
            downStage2DelayMS: nil,
            downStage2Tones: [],
            downStage2Level: 0.0,
            upBaseGaussianAmp: 0.08,
            upBaseDurationMS: 5.0,
            upTones: [
                HapticTone(hz: 260, amp: 0.65, durationMS: 7.5),
                HapticTone(hz: 380, amp: 0.35, durationMS: 6.0),
            ],
            upLevel: 0.34
        ),

        // 6. IBM Model M — loudest buckling spring snap + authentic metallic spring ping
        SwitchProfile(
            id: "ibm-model-m",
            name: "IBM Model M",
            category: "Buckling Spring",
            tagline: "Loud mechanical snap with vintage metallic spring ping",
            stemHex: 0x8D99AE,
            traits: SwitchTraits(thock: 0.62, clack: 1.00, tactility: 1.00),
            downBaseGaussianAmp: 0.18,
            downBaseDurationMS: 4.0,
            downTones: [
                HapticTone(hz: 1420, amp: 0.42, durationMS: 6.5),
                HapticTone(hz: 2640, amp: 0.38, durationMS: 6.0),
                HapticTone(hz: 3920, amp: 0.20, durationMS: 5.5),
            ],
            downLevel: 1.00,
            downStage2DelayMS: 6.5,
            downStage2Tones: [
                HapticTone(hz: 2740, amp: 0.55, durationMS: 22.0),
                HapticTone(hz: 3951, amp: 0.45, durationMS: 18.0),
            ],
            downStage2Level: 0.72,
            upBaseGaussianAmp: 0.10,
            upBaseDurationMS: 3.0,
            upTones: [
                HapticTone(hz: 2520, amp: 0.58, durationMS: 5.5),
                HapticTone(hz: 1320, amp: 0.42, durationMS: 5.5),
            ],
            upLevel: 0.52
        ),

        // 7. Gateron Oil King — factory-lubed creamy, marbly deep linear (richer low-mid than Topre)
        SwitchProfile(
            id: "gateron-oil-king",
            name: "Gateron Oil King",
            category: "Linear · Lubed",
            tagline: "Velvety, factory-lubed deep creamy marbly thock",
            stemHex: 0x3D405B,
            traits: SwitchTraits(thock: 0.92, clack: 0.34, tactility: 0.15),
            downBaseGaussianAmp: 0.20,
            downBaseDurationMS: 7.0,
            downTones: [
                HapticTone(hz: 310, amp: 0.44, durationMS: 12.5),
                HapticTone(hz: 580, amp: 0.38, durationMS: 10.0),
                HapticTone(hz: 860, amp: 0.18, durationMS: 6.5),
            ],
            downLevel: 0.92,
            downStage2DelayMS: nil,
            downStage2Tones: [],
            downStage2Level: 0.0,
            upBaseGaussianAmp: 0.07,
            upBaseDurationMS: 4.0,
            upTones: [
                HapticTone(hz: 510, amp: 0.58, durationMS: 5.5),
                HapticTone(hz: 320, amp: 0.42, durationMS: 6.0),
            ],
            upLevel: 0.32
        ),
    ]

    static func profile(id: String) -> SwitchProfile {
        all.first(where: { $0.id == id }) ?? all[0]
    }
}
