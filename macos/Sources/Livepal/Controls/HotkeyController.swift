import AppKit
import Foundation

@MainActor
final class HotkeyController {
    private var localMonitor: Any?

    var onToggleOverlay: (() -> Void)?
    var onToggleSession: (() -> Void)?

    func start() {
        guard localMonitor == nil else { return }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            guard event.modifierFlags.contains([.command, .shift]) else { return event }

            switch event.charactersIgnoringModifiers?.lowercased() {
            case "l":
                onToggleOverlay?()
                return nil
            case "s":
                onToggleSession?()
                return nil
            default:
                return event
            }
        }
    }

    func stop() {
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        localMonitor = nil
    }
}
