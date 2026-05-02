import ScreenCaptureKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var session: SessionController

    var body: some View {
        NavigationStack {
            Form {
                Section("Incoming audio (ScreenCaptureKit)") {
                    Text(
                        "Livepal captures **system audio from the window you select** (for example Zoom, Meet, or a browser tab). Captions are **on-device only** — no translation step and no paid APIs."
                    )
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                    HStack {
                        Button("Refresh window list") {
                            Task { await session.refreshWindows() }
                        }
                        .disabled(session.isRunning)

                        Spacer()

                        if session.isRunning {
                            ProgressView().controlSize(.small)
                        }
                    }

                    Picker("Call / meeting window", selection: $session.selectedWindowID) {
                        ForEach(session.windows, id: \.windowID) { window in
                            let app = window.owningApplication?.applicationName ?? "App"
                            let title = window.title ?? ""
                            Text("\(app) — \(title)")
                                .tag(Optional(window.windowID))
                        }
                    }
                    .disabled(session.isRunning || session.windows.isEmpty)
                }

                Section("Two caption sections (10 languages, detect + route)") {
                    Picker("First section language", selection: $session.lane1LocaleId) {
                        ForEach(LocaleOptions.captionLaneLocales, id: \.id) { item in
                            Text(item.label).tag(item.id)
                        }
                    }
                    .disabled(session.isRunning)

                    Picker("Second section language", selection: $session.lane2LocaleId) {
                        ForEach(LocaleOptions.captionLaneLocales, id: \.id) { item in
                            Text(item.label).tag(item.id)
                        }
                    }
                    .disabled(session.isRunning)

                    Text(
                        "Designed for **turn-taking**: one remote speaker at a time (for example English, then Spanish). The app runs **two recognizers** on the same incoming audio and uses **Apple’s language classifier** to send each phrase to the **first** or **second** section. Only **one** section shows a **live** partial at once; the other keeps the last **finished** line. Ten spoken languages are supported in this build; pick the two that match your call."
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }

                Section("Caption overlay") {
                    Button("Toggle caption bar") {
                        session.toggleHUD()
                    }

                    Text(session.statusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Section {
                    HStack {
                        Button("Start") {
                            Task { await session.startSession() }
                        }
                        .keyboardShortcut(.return, modifiers: [.command])
                        .disabled(session.isRunning)

                        Button("Stop", role: .destructive) {
                            Task { await session.stopSession() }
                        }
                        .disabled(!session.isRunning)
                    }
                }
            }
            .navigationTitle("Livepal")
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
}
