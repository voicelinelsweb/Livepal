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
    @Published var selectedSection: SettingsSection = .session
    @Published var overlayPreferences: OverlayPreferences
    @Published var permissionSummary: String = ""
    @Published var healthWarning: String = ""
    @Published var profileNameDraft: String = "Team call"

    let captionModel = CaptionContentModel()
    let profileStore = ProfileStore()

    private let capture = SystemAudioCapture()
    private let hud = CaptionHUDController()
    private let hotkeys = HotkeyController()
    private let permissionMonitor = PermissionHealthMonitor()

    private var coordinator: DualLaneSpeechCoordinator?
    private var hudVisible = false
    private var runtimeState = RuntimeHealthState()
    private var healthTask: Task<Void, Never>?

    private let defaults = UserDefaults.standard

    init() {
        lane1LocaleId = defaults.string(forKey: Keys.lane1LocaleId) ?? "en-US"
        lane2LocaleId = defaults.string(forKey: Keys.lane2LocaleId) ?? "es-ES"
        overlayPreferences = OverlayPreferences.load(from: defaults)
        captionModel.fontSize = overlayPreferences.fontSize
        captionModel.panelOpacity = overlayPreferences.opacity
        clampLaneLocaleIds()
        updatePermissionSummary()
        configureHotkeys()
    }


    func syncLanePairAfterEdit() {
        clampLaneLocaleIds()
    }

    func persistSettings() {
        clampLaneLocaleIds()
        defaults.set(lane1LocaleId, forKey: Keys.lane1LocaleId)
        defaults.set(lane2LocaleId, forKey: Keys.lane2LocaleId)
        overlayPreferences.persist(to: defaults)
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
            hud.show(model: captionModel, preferences: overlayPreferences)
            hudVisible = true
        }
    }

    func updateOverlayPreferences() {
        captionModel.fontSize = overlayPreferences.fontSize
        captionModel.panelOpacity = overlayPreferences.opacity
        hud.update(preferences: overlayPreferences)
        persistSettings()
    }

    func saveCurrentProfile() {
        let trimmed = profileNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        profileStore.saveProfile(name: trimmed, lane1: lane1LocaleId, lane2: lane2LocaleId, overlay: overlayPreferences)
        statusMessage = "Saved profile \"\(trimmed)\"."
    }

    func loadProfile(_ profile: SessionProfile) {
        lane1LocaleId = profile.lane1LocaleId
        lane2LocaleId = profile.lane2LocaleId
        overlayPreferences = profile.overlay
        updateOverlayPreferences()
        syncLanePairAfterEdit()
        statusMessage = "Loaded profile \"\(profile.name)\"."
    }

    func startSession() async {
        persistSettings()
        updatePermissionSummary()

        captionModel.lane1Title = LocaleOptions.shortTitle(for: lane1LocaleId)
        captionModel.lane2Title = LocaleOptions.shortTitle(for: lane2LocaleId)
        captionModel.lane1Line = ""
        captionModel.lane2Line = ""
        captionModel.lane1Confidence = 0
        captionModel.lane2Confidence = 0

        guard let windowID = selectedWindowID,
              let window = windows.first(where: { $0.windowID == windowID })
        else {
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

        coord.start { [weak self] lane1, lane2, c1, c2 in
            guard let self else { return }
            self.captionModel.lane1Line = lane1
            self.captionModel.lane2Line = lane2
            self.captionModel.lane1Confidence = c1
            self.captionModel.lane2Confidence = c2
            self.runtimeState.markCaption()
        }

        capture.onCaptureError = { [weak self] error in
            Task { @MainActor in
                self?.healthWarning = "Capture interrupted: \(error.localizedDescription). Attempting recovery…"
                await self?.attemptRestartWithBackoff()
            }
        }

        do {
            try await capture.start(window: window) { [weak self] buffer in
                guard let self else { return }
                Task { @MainActor in
                    self.runtimeState.markAudio()
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
            hud.show(model: captionModel, preferences: overlayPreferences)
            hudVisible = true
        } else {
            hud.update(preferences: overlayPreferences)
        }

        isRunning = true
        statusMessage = "Listening (on-device). Incoming: \(window.title ?? "window")."
        startHealthWatchdog()
    }

    func stopSession() async {
        coordinator?.stop()
        coordinator = nil
        try? await capture.stop()
        isRunning = false
        statusMessage = "Stopped."
        healthTask?.cancel()
        healthTask = nil
    }

    func toggleSessionViaHotkey() {
        if isRunning {
            Task { await stopSession() }
        } else {
            Task { await startSession() }
        }
    }

    private func updatePermissionSummary() {
        permissionSummary = permissionMonitor.snapshot().summary
    }

    private func configureHotkeys() {
        hotkeys.onToggleOverlay = { [weak self] in
            self?.toggleHUD()
        }
        hotkeys.onToggleSession = { [weak self] in
            self?.toggleSessionViaHotkey()
        }
        hotkeys.start()
    }

    private func startHealthWatchdog() {
        healthTask?.cancel()
        healthTask = Task { [weak self] in
            while let self, !Task.isCancelled, self.isRunning {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                let now = Date()
                if let lastAudio = self.runtimeState.lastAudioAt,
                   now.timeIntervalSince(lastAudio) > 6 {
                    self.healthWarning = "No incoming audio detected for 6s. Check selected window and permissions."
                }
                if let lastCaption = self.runtimeState.lastCaptionAt,
                   now.timeIntervalSince(lastCaption) > 8 {
                    self.healthWarning = "No captions for 8s. Speech might not match selected lane locales."
                }
            }
        }
    }

    private func attemptRestartWithBackoff() async {
        guard isRunning else { return }
        runtimeState.restartCount += 1
        let delay = min(3.0, Double(runtimeState.restartCount))
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

        await stopSession()
        await startSession()
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

    private enum Keys {
        static let lane1LocaleId = "livepal.lane1LocaleId"
        static let lane2LocaleId = "livepal.lane2LocaleId"
    }
}
