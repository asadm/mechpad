# MechPad

Simulate mechanical keyboard switch sounds directly through your MacBook's **Force Touch trackpad** — **no speakers required**.

> Inspired by [os6/nospeaker](https://github.com/os6/nospeaker) by Cody Collier, which pioneered driving the MacBook Force Touch haptic motor via macOS's `MultitouchSupport` framework (`MTActuationCreateFromDictionary` + `MTActuationActuate`) to synthesize audio directly from the trackpad glass.

## Demo

*Mute your Mac. Every click below comes straight from the MacBook Pro's Force Touch trackpad:*

<video src="https://github.com/asadm/mechpad/raw/main/demo_cleaned.mp4" controls width="360"></video>

*(If the inline player doesn't load, watch or download [demo_cleaned.mp4](demo_cleaned.mp4) directly.)*

## Switch Profiles

Each profile is acoustically calibrated against the MacBook trackpad's physical frequency response:

| Profile | Type | Character |
| --- | --- | --- |
| **Cherry MX Blue** | Clicky | Bright click-jacket snap + sharp clack |
| **Cherry MX Brown** | Tactile | Dry, crisp mid-range tactile notch |
| **Cherry MX Red** | Linear | Smooth, soft linear bottom-out |
| **Holy Panda** | Tactile · Thock | Pronounced hollow woody pop |
| **Topre 45g** | Electrostatic | Deepest, muted HHKB rubber-dome thock |
| **IBM Model M** | Buckling Spring | Loud mechanical snap + sustained metallic ping |
| **Gateron Oil King** | Linear · Lubed | Creamy, marbly deep factory-lubed linear |

## Features

- **Zero speakers used**: Mute your Mac and place it on a hard desk for best resonance.
- **System-wide typing**: Passive listen-only `CGEventTap` clicks in every macOS app (requires Accessibility permission).
- **Instant Typing Test Pad**: Audition switches inside MechPad immediately before granting Accessibility access.
- **Stabilizer acoustics**: Spacebar, Return, Delete, and Modifier keys produce deeper, heavier resonance.
- **Key-up return clicks**: Simulates top-out switch return when releasing keys (toggleable).
- **Menu bar app**: Lives in the menu bar with no Dock icon. Switch profiles and change intensity from the menu; right-click the icon to pause or resume.
- **Launch at login**: Optional, from the setup screen, settings or the menu.
- **Built-in keyboard only**: Optionally stay quiet when you type on an external keyboard.
- **Private by design**: Only key codes are used, never the characters you type. Keystrokes posted by other apps (for example keyboard layout switchers) are ignored.
- **Languages**: English, Russian, Hebrew, German, Spanish, French, Japanese and Simplified Chinese.

## Download & Install

Grab the latest universal macOS build (`Apple Silicon + Intel`) from [GitHub Releases](../../releases/latest):

1. Download and unzip `MechPad.zip`.
2. Move `MechPad.app` to `/Applications` (or run directly).
3. On first launch, right-click → **Open** if Gatekeeper prompts (ad-hoc signed build).
4. Click **Grant Access** in the app banner (or enable **MechPad** under **System Settings → Privacy & Security → Accessibility**) to hear clicks while typing in other apps.

## Build from Source

Requires macOS 13+ and Xcode Command Line Tools (`xcode-select --install`):

```sh
./build.sh            # native build for this Mac
./build.sh universal  # universal binary (arm64 + x86_64)
open MechPad.app
```

## Credits

- Trackpad haptic motor technique inspired by [os6/nospeaker](https://github.com/os6/nospeaker) (MIT License).
