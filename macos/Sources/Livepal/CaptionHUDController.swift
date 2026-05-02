import AppKit
import SwiftUI

@MainActor
final class CaptionHUDController {
    private var panel: NSPanel?
    private var latestPreferences = OverlayPreferences()

    func show(model: CaptionContentModel, preferences: OverlayPreferences) {
        latestPreferences = preferences
        if panel == nil {
            createPanel(model: model)
        }
        apply(preferences: preferences)
        panel?.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    func update(preferences: OverlayPreferences) {
        latestPreferences = preferences
        apply(preferences: preferences)
    }

    private func createPanel(model: CaptionContentModel) {
        let rootView = CaptionBarView().environmentObject(model)
        let hosting = NSHostingView(rootView: rootView)
        hosting.translatesAutoresizingMaskIntoConstraints = false

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: latestPreferences.width, height: latestPreferences.height),
            styleMask: [.nonactivatingPanel, .hudWindow, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.contentView = hosting
        panel.setFrameAutosaveName("LivepalCaptionHUD")
        panel.center()

        self.panel = panel
    }

    private func apply(preferences: OverlayPreferences) {
        guard let panel else { return }
        var frame = panel.frame
        frame.size.width = max(600, preferences.width)
        frame.size.height = max(150, preferences.height)

        if let screenFrame = panel.screen?.visibleFrame ?? NSScreen.main?.visibleFrame {
            let x = screenFrame.midX - frame.width / 2
            let y: CGFloat
            switch preferences.anchor {
            case .top:
                y = screenFrame.maxY - frame.height - 30
            case .middle:
                y = screenFrame.midY - frame.height / 2
            case .bottom:
                y = screenFrame.minY + 40
            }
            frame.origin = CGPoint(x: x, y: y)
        }

        panel.alphaValue = preferences.opacity
        panel.setFrame(frame, display: true, animate: true)
    }
}

struct CaptionBarView: View {
    @EnvironmentObject private var model: CaptionContentModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            laneRow(title: model.lane1Title.isEmpty ? "Section 1" : model.lane1Title,
                    text: model.lane1Line,
                    confidence: model.lane1Confidence,
                    color: DS.Colors.laneA)

            Divider().overlay(Color.white.opacity(0.14))

            laneRow(title: model.lane2Title.isEmpty ? "Section 2" : model.lane2Title,
                    text: model.lane2Line,
                    confidence: model.lane2Confidence,
                    color: DS.Colors.laneB)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(model.panelOpacity))
                .background(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
        )
        .padding(10)
    }

    @ViewBuilder
    private func laneRow(title: String, text: String, confidence: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(confidence * 100))%")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Text(text.isEmpty ? "Listening…" : text)
                .font(.system(size: model.fontSize, weight: .medium, design: .rounded))
                .foregroundStyle(color)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(4)
                .minimumScaleFactor(0.65)
                .animation(.easeOut(duration: 0.15), value: text)
        }
    }
}
