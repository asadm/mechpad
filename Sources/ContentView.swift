import SwiftUI

struct ContentView: View {
    @ObservedObject var state: AppState
    @State private var sandboxText: String = ""
    @State private var isPulsing: Bool = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !state.engine.isAvailable {
                        hardwareWarningBanner
                    } else if !state.hasGlobalAccess {
                        accessibilityBanner
                    }

                    profileSection
                    tuningSection
                    sandboxSection
                }
                .padding(18)
            }
        }
        .frame(minWidth: 640, idealWidth: 680, minHeight: 620, idealHeight: 700)
        .background(Color(nsColor: .windowBackgroundColor))
        .onChange(of: state.pulseCounter) { _ in
            isPulsing = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.11) {
                isPulsing = false
            }
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(state.selectedProfile.stemColor.opacity(0.18))
                    .frame(width: 38, height: 38)
                SwitchStemIcon(color: state.selectedProfile.stemColor)
                    .frame(width: 22, height: 22)
                    .scaleEffect(isPulsing ? 0.88 : 1.0)
                    .animation(.easeOut(duration: 0.08), value: isPulsing)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text("MechPad")
                        .font(.system(size: 16, weight: .bold))
                    Text("TRACKPAD HAPTICS")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.14))
                        .clipShape(Capsule())
                }
                HStack(spacing: 6) {
                    Circle()
                        .fill(state.engine.isAvailable ? Color.green : Color.red)
                        .frame(width: 7, height: 7)
                    Text(state.engine.deviceDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if state.hasGlobalAccess {
                        Text("· Global Typing Active")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }

            Spacer()

            Toggle(isOn: $state.isEnabled) {
                Text(state.isEnabled ? "Active" : "Paused")
                    .font(.system(size: 12, weight: .medium))
            }
            .toggleStyle(.switch)
            .controlSize(.small)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
    }

    // MARK: - Status Banners

    private var hardwareWarningBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text("Force Touch Trackpad Unavailable")
                    .font(.subheadline.bold())
                Text(state.engine.errorMessage ?? "No compatible Force Touch actuator was found.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.orange.opacity(0.12))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.orange.opacity(0.3), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var accessibilityBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "hand.raised.fill")
                .foregroundColor(.accentColor)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text("Enable Global Keyboard Sound")
                    .font(.subheadline.bold())
                Text("Grant Accessibility permission so MechPad clicks while typing in any app. You can still test below right now.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button("Grant Access") {
                state.monitor.requestAccessibilityPermission()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(12)
        .background(Color.accentColor.opacity(0.10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.accentColor.opacity(0.28), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Profiles Grid

    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Switch Profiles")
                    .font(.headline)
                Spacer()
                Text("No speakers used — sound comes from your trackpad")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(SwitchLibrary.all) { profile in
                    SwitchCard(
                        profile: profile,
                        isSelected: state.selectedProfileID == profile.id,
                        onSelect: {
                            state.selectedProfileID = profile.id
                            state.audition(profile: profile)
                        },
                        onTest: {
                            state.audition(profile: profile)
                        }
                    )
                }
            }
        }
    }

    // MARK: - Tuning Controls

    private var tuningSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Acoustics & Feel")
                .font(.headline)

            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "waveform")
                        .foregroundColor(.secondary)
                        .frame(width: 18)
                    Text("Intensity")
                        .font(.subheadline)
                        .frame(width: 68, alignment: .leading)
                    Slider(value: $state.intensity, in: 0.15...1.0)
                    Text("\(Int((state.intensity * 100).rounded()))%")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 38, alignment: .trailing)
                }

                Divider()

                HStack(spacing: 24) {
                    Toggle("Key-Up Return Sound", isOn: $state.playKeyUp)
                        .font(.subheadline)
                    Toggle("Stabilizer Acoustics (Space / Enter / Shift)", isOn: $state.useKeyAcoustics)
                        .font(.subheadline)
                    Toggle("Built-in Keyboard Only", isOn: $state.builtInOnly)
                        .font(.subheadline)
                        .help("Stay quiet when you type on an external keyboard")
                    Spacer()
                }
            }
            .padding(14)
            .background(Color(nsColor: .controlBackgroundColor))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.08), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - Live Typing Sandbox

    private var sandboxSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Typing Test Pad")
                    .font(.headline)
                Spacer()
                HStack(spacing: 8) {
                    Text("Clicks: \(state.totalClicks)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)

                    Text(state.lastKeyLabel)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(isPulsing ? state.selectedProfile.stemColor.opacity(0.35) : Color.secondary.opacity(0.14))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(state.selectedProfile.stemColor.opacity(isPulsing ? 0.9 : 0.25), lineWidth: 1)
                        )
                        .scaleEffect(isPulsing ? 1.08 : 1.0)
                        .animation(.easeOut(duration: 0.09), value: isPulsing)
                }
            }

            HStack(spacing: 10) {
                TextField("Type here to test \(state.selectedProfile.name)… (mute your Mac speakers!)", text: $sandboxText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, design: .monospaced))
                    .padding(10)
                    .background(Color(nsColor: .textBackgroundColor))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.12), lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Button("Spacebar") {
                    state.audition(profile: state.selectedProfile, keyKind: .spacebar)
                }
                .controlSize(.regular)
            }
        }
    }
}

// MARK: - Switch Card

private struct SwitchCard: View {
    let profile: SwitchProfile
    let isSelected: Bool
    let onSelect: () -> Void
    let onTest: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top, spacing: 10) {
                SwitchStemIcon(color: profile.stemColor)
                    .frame(width: 26, height: 26)
                    .padding(5)
                    .background(profile.stemColor.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.name)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    Text(profile.category.uppercased())
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(profile.stemColor)
                }

                Spacer(minLength: 4)

                Button(action: onTest) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 9))
                        .padding(6)
                        .background(Color.primary.opacity(0.07))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Test \(profile.name) sound")
            }

            Text(profile.tagline)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                TraitBar(label: "Thock", value: profile.traits.thock, color: profile.stemColor)
                TraitBar(label: "Clack", value: profile.traits.clack, color: profile.stemColor)
                TraitBar(label: "Bump", value: profile.traits.tactility, color: profile.stemColor)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(isSelected ? profile.stemColor.opacity(0.09) : Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(isSelected ? profile.stemColor : Color.primary.opacity(0.08), lineWidth: isSelected ? 1.8 : 1)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
    }
}

private struct TraitBar: View {
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.09))
                    Capsule().fill(color.opacity(0.85))
                        .frame(width: max(4, geo.size.width * value))
                }
            }
            .frame(height: 4)
        }
    }
}

/// Miniature Cherry MX-style cross-stem icon.
private struct SwitchStemIcon: View {
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                RoundedRectangle(cornerRadius: w * 0.18, style: .continuous)
                    .stroke(color.opacity(0.55), lineWidth: 1.5)
                RoundedRectangle(cornerRadius: w * 0.08)
                    .fill(color)
                    .frame(width: w * 0.24, height: h * 0.62)
                RoundedRectangle(cornerRadius: w * 0.08)
                    .fill(color)
                    .frame(width: w * 0.62, height: h * 0.24)
            }
        }
    }
}
