import CoreGraphics
import Foundation
import Speech

struct PermissionHealthSnapshot {
    let screenCaptureAllowed: Bool
    let speechStatus: SFSpeechRecognizerAuthorizationStatus

    var summary: String {
        if !screenCaptureAllowed {
            return "Screen Recording permission is not granted."
        }
        switch speechStatus {
        case .authorized:
            return "Permissions look healthy."
        case .denied:
            return "Speech recognition permission is denied."
        case .restricted:
            return "Speech recognition is restricted on this Mac."
        case .notDetermined:
            return "Speech recognition permission not determined yet."
        @unknown default:
            return "Speech recognition permission state is unknown."
        }
    }
}

@MainActor
final class PermissionHealthMonitor {
    func snapshot() -> PermissionHealthSnapshot {
        let screen = CGPreflightScreenCaptureAccess()
        let speech = SFSpeechRecognizer.authorizationStatus()
        return PermissionHealthSnapshot(screenCaptureAllowed: screen, speechStatus: speech)
    }
}
