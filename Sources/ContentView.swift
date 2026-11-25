import SwiftUI

struct ContentView: View {
    @ObservedObject var state: AppState
    var onClose: () -> Void = {}
    @State private var tryText: String = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            Form {
                setupSection
                profileSection
                soundSection
                generalSection
            }
            .formStyle(.grouped)
            Divider()
            tryBar
        }
        .frame(minWidth: 480, idealWidth: 520, minHeight: 560, idealHeight: 680)
    }

    // MARK: - Header

    private var statusColor: Color {
        switch state.status {
        case .active: return .green
        case .paused: return .orange
        case .needsAccess: return .red
        case .noTrackpad: return .secondary
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 40, height: 40)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("MechPad")
                    .font(.headline)
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                        .accessibilityHidden(true)
                    Text(state.statusTitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Toggle("Keyboard clicks", isOn: $state.isEnabled)
                .toggleStyle(.switch)
                .labelsHidden()
                .help(state.isEnabled ? Text("Pause clicks") : Text("Resume clicks"))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - Setup

    @ViewBuilder
    private var setupSection: some View {
        switch state.status {
        case .noTrackpad:
            Section {
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("No Force Touch trackpad found").font(.headline)
                        Text(state.engine.errorMessage.map { NSLocalizedString($0, comment: "") } ?? String(localized: "MechPad needs a MacBook or a Magic Trackpad 2 or later."))
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                }
            }
        case .needsAccess:
            Section {
                Label {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Let MechPad hear your typing").font(.headline)
                        Text("macOS asks for Accessibility access so MechPad can click on every key press in any app. MechPad only uses key presses to make clicks. It never saves or sends what you type.")
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Button("Grant Access…") { state.monitor.requestAccessibilityPermission() }
                            .buttonStyle(.borderedProminent)
                            .padding(.top, 2)
                    }
                } icon: {
                    Image(systemName: "hand.raised.fill").foregroundStyle(Color.accentColor)
                }
            } footer: {
                Text("Until then, you can try the clicks in the field at the bottom.")
            }
        case .active, .paused:
            if !state.setupDone {
                Section {
                    Label {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("You're all set").font(.headline)
                            Text("MechPad lives in the menu bar: look for the keycap icon at the top of your screen. You can close this window.")
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            HStack {
                                Toggle("Launch at login", isOn: launchAtLoginBinding)
                                Spacer()
                                Button("Done") {
                                    state.setupDone = true
                                    onClose()
                                }
                                .keyboardShortcut(.defaultAction)
                            }
                            .padding(.top, 2)
                        }
                    } icon: {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    }
                }
            }
        }
    }

    // MARK: - Profiles

    private var profileSection: some View {
        Section {
            ForEach(SwitchLibrary.all) { profile in
                ProfileRow(
                    profile: profile,
                    isSelected: profile.id == state.selectedProfileID,
                    onSelect: {
                        state.selectedProfileID = profile.id
                        state.audition(profile: profile)
                    },
                    onPreview: { state.audition(profile: profile) }
                )
            }
        } header: {
            Text("Switch")
        }
    }

    // MARK: - Sound

    private var soundSection: some View {
        Section("Sound") {
            LabeledContent("Intensity") {
                HStack(spacing: 10) {
                    Slider(value: $state.intensity, in: 0.15...1.0)
                        .accessibilityLabel("Intensity")
                    Text("\(Int((state.intensity * 100).rounded()))%")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 40, alignment: .trailing)
                }
            }
            Toggle("Sound on key release", isOn: $state.playKeyUp)
            Toggle("Deeper sound for large keys", isOn: $state.useKeyAcoustics)
                .help("Space, Return, Delete, Tab, Esc and modifier keys")
            Toggle("Only the Mac's built-in keyboard", isOn: $state.builtInOnly)
                .help("Stay quiet when you type on an external keyboard")
        }
    }

    // MARK: - General

    private var generalSection: some View {
        Section {
            Toggle("Launch at login", isOn: launchAtLoginBinding)
        } header: {
            Text("General")
        } footer: {
            Text("Clicks pause in password fields: macOS hides those key presses from every app.")
        }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(get: { state.launchAtLogin }, set: { state.setLaunchAtLogin($0) })
    }

    // MARK: - Try bar

    private var tryBar: some View {
        HStack(spacing: 10) {
            TextField("Type here to try \(state.selectedProfile.name)", text: $tryText)
                .textFieldStyle(.roundedBorder)
            Button("Space") {
                state.audition(profile: state.selectedProfile, keyKind: .spacebar)
            }
            .help("Play a space bar click")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

// MARK: - Profile row

private struct ProfileRow: View {
    let profile: SwitchProfile
    let isSelected: Bool
    let onSelect: () -> Void
    let onPreview: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onSelect) {
                HStack(spacing: 10) {
                    SwitchStemIcon(color: profile.stemColor)
                        .frame(width: 18, height: 18)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(profile.name)
                            Text(profile.localizedCategory)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if isSelected {
                            Text(profile.localizedTagline)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .opacity(isSelected ? 1 : 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: "\(profile.name), \(profile.localizedCategory)"))
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)

            Button(action: onPreview) {
                Image(systemName: "play.circle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help("Preview \(profile.name)")
            .accessibilityLabel("Preview \(profile.name)")
        }
        .padding(.vertical, 2)
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
                    .stroke(color.opacity(0.6), lineWidth: 1.5)
                RoundedRectangle(cornerRadius: w * 0.08)
                    .fill(color)
                    .frame(width: w * 0.24, height: h * 0.62)
                RoundedRectangle(cornerRadius: w * 0.08)
                    .fill(color)
                    .frame(width: w * 0.62, height: h * 0.24)
            }
        }
        .accessibilityHidden(true)
    }
}
