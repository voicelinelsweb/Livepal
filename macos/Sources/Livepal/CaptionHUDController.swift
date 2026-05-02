import AppKit
import SwiftUI

@MainActor
final class CaptionHUDController {
    private var panel: NSPanel?

    func show(model: CaptionContentModel) {
        if panel != nil { return }

        let rootView = CaptionBarView().environmentObject(model)
        let hosting = NSHostingView(rootView: rootView)
        hosting.translatesAutoresizingMaskIntoConstraints = false

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 980, height: 240),
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
        panel.orderFrontRegardless()

        self.panel = panel
    }

    func hide() {
        panel?.orderOut(nil)
        panel = nil
    }
}

struct CaptionBarView: View {
    @EnvironmentObject private var model: CaptionContentModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(model.lane1Title.isEmpty ? "Section 1" : model.lane1Title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(model.lane1Line.isEmpty ? "…" : model.lane1Line)
                .font(.system(size: 28, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(4)
                .minimumScaleFactor(0.6)

            Divider()
                .overlay(Color.white.opacity(0.12))

            Text(model.lane2Title.isEmpty ? "Section 2" : model.lane2Title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(model.lane2Line.isEmpty ? "…" : model.lane2Line)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(red: 0.65, green: 0.85, blue: 1.0))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(4)
                .minimumScaleFactor(0.6)
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.82))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
        )
        .padding(10)
    }
}
