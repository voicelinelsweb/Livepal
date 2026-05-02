import Foundation
import ScreenCaptureKit
import Speech
import SwiftUI

@MainActor
final class SessionController: ObservableObject {
    @Published var windows: [SCWindow] = []
    @Published var selectedWindowID: UInt32?
    @Published var lane1LocaleId: String = "en-US"
    @Published var lane2LocaleId: String = "es-ES"
    @Published var isRunning: Bool = false
    @Published var statusMessage: String = "Pick the call window, grant permissions, then Start."

    let captionModel = CaptionContentModel()

    private let capture = SystemAudioCapture()
    private let hud = CaptionHUDController()
    private var coordinator: DualLaneSpeechCoordinator?

    private let defaults = UserDefaults.standard

    init() {
        lane1LocaleId = defaults.string(forKey: Keys.lane1LocaleId) ?? "en-US"
        lane2LocaleId = defaults.string(forKey: Keys.lane2LocaleId) ?? "es-ES"
        clampLaneLocaleIds()
    }

    /// Call after the user edits a language picker so the pair stays valid in the UI (not only on Start).
    func syncLanePairAfterEdit() {
        clampLaneLocaleIds()
    }

    /// Keeps saved settings valid when the supported language list changes.
    private func clampLaneLocaleIds() {
        if !LocaleOptions.supportedLocaleIds.contains(lane1LocaleId) {
            lane1LocaleId = "en-US"
        }
        if !LocaleOptions.supportedLocaleIds.contains(lane2LocaleId) {
            lane2LocaleId = "es-ES"
        }
        if lane1LocaleId == lane2LocaleId {
            lane2LocaleId = LocaleOptions.defaultPairing(secondLaneIfFirstIs: lane1LocaleId)
        }
    }

    func persistSettings() {
        clampLaneLocaleIds()
        defaults.set(lane1LocaleId, forKey: Keys.lane1LocaleId)
        defaults.set(lane2LocaleId, forKey: Keys.lane2LocaleId)
    }

    func refreshWindows() async {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            let filtered = content.windows.filter { window in
                guard let title = window.title, !title.isEmpty else { return false }
                guard window.owningApplication != nil else { return false }
                return true
            }
            .sorted {
                let a = "\($0.owningApplication?.applicationName ?? "") \($0.title ?? "")"
                let b = "\($1.owningApplication?.applicationName ?? "") \($1.title ?? "")"
                return a.localizedCaseInsensitiveCompare(b) == .orderedAscending
            }
            windows = filtered
            if selectedWindowID == nil {
                selectedWindowID = filtered.first?.windowID
            }
            statusMessage = "Found \(filtered.count) capturable windows."
        } catch {
            statusMessage = "Could not list windows: \(error.localizedDescription)"
        }
    }

    func toggleHUD() {
        if hudVisible {
            hud.hide()
            hudVisible = false
        } else {
            hud.show(model: captionModel)
            hudVisible = true
        }
    }

    private var hudVisible = false

    func startSession() async {
        persistSettings()

        captionModel.lane1Title = LocaleOptions.shortTitle(for: lane1LocaleId)
        captionModel.lane2Title = LocaleOptions.shortTitle(for: lane2LocaleId)
        captionModel.lane1Line = ""
        captionModel.lane2Line = ""

        guard let windowID = selectedWindowID, let window = windows.first(where: { $0.windowID == windowID }) else {
            statusMessage = "Select a window first."
            return
        }

        do {
            try await ensureSpeechAuthorized()
        } catch {
            statusMessage = error.localizedDescription
            return
        }

        let coord: DualLaneSpeechCoordinator
        do {
            coord = try DualLaneSpeechCoordinator(lane1LocaleId: lane1LocaleId, lane2LocaleId: lane2LocaleId)
        } catch {
            statusMessage = error.localizedDescription
            return
        }

        coordinator = coord

        coord.start { [weak self] lane1, lane2 in
            guard let self else { return }
            self.captionModel.lane1Line = lane1
            self.captionModel.lane2Line = lane2
        }

        do {
            try await capture.start(window: window) { [weak self] buffer in
                guard let self else { return }
                Task { @MainActor in
                    self.coordinator?.append(buffer: buffer)
                }
            }
        } catch {
            coordinator?.stop()
            coordinator = nil
            statusMessage = "Could not start capture: \(error.localizedDescription)"
            return
        }

        if !hudVisible {
            hud.show(model: captionModel)
            hudVisible = true
        }

        isRunning = true
        statusMessage = "Listening (on-device). Incoming: \(window.title ?? "window")."
    }

    func stopSession() async {
        coordinator?.stop()
        coordinator = nil

        try? await capture.stop()

        isRunning = false
        statusMessage = "Stopped."
    }

    private func ensureSpeechAuthorized() async throws {
        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        switch status {
        case .authorized:
            return
        case .denied:
            throw NSError(domain: "Livepal", code: 20, userInfo: [NSLocalizedDescriptionKey: "Speech recognition is denied. Enable it in System Settings → Privacy & Security → Speech Recognition."])
        case .restricted:
            throw NSError(domain: "Livepal", code: 21, userInfo: [NSLocalizedDescriptionKey: "Speech recognition is restricted on this Mac."])
        case .notDetermined:
            throw NSError(domain: "Livepal", code: 22, userInfo: [NSLocalizedDescriptionKey: "Speech recognition permission was not determined."])
        @unknown default:
            throw NSError(domain: "Livepal", code: 23, userInfo: [NSLocalizedDescriptionKey: "Speech recognition is not available."])
        }
    }

    private enum Keys {
        static let lane1LocaleId = "livepal.lane1LocaleId"
        static let lane2LocaleId = "livepal.lane2LocaleId"
    }
}
