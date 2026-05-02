import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var session: SessionController

    var body: some View {
        NavigationSplitView {
            SettingsSidebarView(selected: $session.selectedSection)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    header
                    panelForSection(session.selectedSection)
                }
                .padding(DS.Spacing.lg)
            }
            .background(DS.Colors.bg)
        }
        .onChange(of: session.lane1LocaleId) { _, _ in
            session.syncLanePairAfterEdit()
        }
        .onChange(of: session.lane2LocaleId) { _, _ in
            session.syncLanePairAfterEdit()
        }
        .task {
            await session.refreshWindows()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text("Livepal v2")
                .font(.largeTitle.weight(.bold))
            Text("Premium bilingual live captions for turn-taking calls.")
                .foregroundStyle(.secondary)

            if !session.healthWarning.isEmpty {
                Label(session.healthWarning, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(DS.Colors.warning)
                    .font(.footnote)
                    .glassCard()
            }
        }
    }

    @ViewBuilder
    private func panelForSection(_ section: SettingsSection) -> some View {
        switch section {
        case .session:
            SessionPanelView()
                .environmentObject(session)

        case .overlay:
            overlayPanel

        case .language:
            languagePanel

        case .advanced:
            advancedPanel
        }
    }

    private var overlayPanel: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Overlay")
                .font(.title3.weight(.semibold))

            HStack {
                Text("Position")
                Picker("", selection: $session.overlayPreferences.anchor) {
                    ForEach(HUDVerticalAnchor.allCases) { anchor in
                        Text(anchor.label).tag(anchor)
                    }
                }
                .labelsHidden()
            }

            HStack {
                Text("Opacity")
                Slider(value: $session.overlayPreferences.opacity, in: 0.5...1)
                Text(String(format: "%.2f", session.overlayPreferences.opacity))
                    .font(.caption.monospacedDigit())
            }

            HStack {
                Text("Font size")
                Slider(value: $session.overlayPreferences.fontSize, in: 18...46)
                Text("\(Int(session.overlayPreferences.fontSize))")
                    .font(.caption.monospacedDigit())
            }

            HStack {
                Text("Width")
                Slider(value: $session.overlayPreferences.width, in: 700...1400)
                Text("\(Int(session.overlayPreferences.width))")
                    .font(.caption.monospacedDigit())
            }

            HStack {
                Text("Height")
                Slider(value: $session.overlayPreferences.height, in: 150...400)
                Text("\(Int(session.overlayPreferences.height))")
                    .font(.caption.monospacedDigit())
            }

            HStack {
                Button("Apply overlay changes") {
                    session.updateOverlayPreferences()
                }
                Button("Toggle caption HUD") {
                    session.toggleHUD()
                }
            }
        }
        .glassCard()
    }

    private var languagePanel: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Language lanes")
                .font(.title3.weight(.semibold))
            Text("Choose two of the 10 supported locales for bilingual caption routing.")
                .foregroundStyle(.secondary)

            Picker("Lane 1", selection: $session.lane1LocaleId) {
                ForEach(LocaleOptions.captionLaneLocales, id: \.id) { item in
                    Text(item.label).tag(item.id)
                }
            }
            Picker("Lane 2", selection: $session.lane2LocaleId) {
                ForEach(LocaleOptions.captionLaneLocales, id: \.id) { item in
                    Text(item.label).tag(item.id)
                }
            }

            Text("Hotkeys: Cmd+Shift+S start/stop session, Cmd+Shift+L toggle overlay.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .glassCard()
    }

    private var advancedPanel: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Advanced")
                .font(.title3.weight(.semibold))

            Text("Permissions: \(session.permissionSummary)")
                .foregroundStyle(.secondary)

            Divider()

            Text("Profiles")
                .font(.headline)

            HStack {
                TextField("Profile name", text: $session.profileNameDraft)
                Button("Save current") {
                    session.saveCurrentProfile()
                }
            }

            if session.profileStore.profiles.isEmpty {
                Text("No saved profiles yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(session.profileStore.profiles) { profile in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(profile.name)
                            Text("\(LocaleOptions.shortTitle(for: profile.lane1LocaleId)) / \(LocaleOptions.shortTitle(for: profile.lane2LocaleId))")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Load") { session.loadProfile(profile) }
                        Button("Delete", role: .destructive) { session.profileStore.delete(profile) }
                    }
                }
            }
        }
        .glassCard()
    }
}
