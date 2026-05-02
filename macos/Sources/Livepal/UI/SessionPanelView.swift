import ScreenCaptureKit
import SwiftUI

struct SessionPanelView: View {
    @EnvironmentObject private var session: SessionController

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Incoming Audio")
                .font(.title3.weight(.semibold))

            Text("Capture system audio from a selected call window.")
                .foregroundStyle(.secondary)

            HStack {
                Button("Refresh windows") {
                    Task { await session.refreshWindows() }
                }
                .disabled(session.isRunning)

                Spacer()

                if session.isRunning {
                    Label("Listening", systemImage: "waveform")
                        .foregroundStyle(DS.Colors.success)
                }
            }

            Picker("Call window", selection: $session.selectedWindowID) {
                ForEach(session.windows, id: \.windowID) { window in
                    let app = window.owningApplication?.applicationName ?? "App"
                    let title = window.title ?? ""
                    Text("\(app) — \(title)")
                        .tag(Optional(window.windowID))
                }
            }
            .disabled(session.isRunning || session.windows.isEmpty)

            Divider()

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

                Spacer()
                Text(session.statusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .glassCard()
    }
}
