import Foundation

struct RuntimeHealthState {
    var lastAudioAt: Date?
    var lastCaptionAt: Date?
    var restartCount: Int = 0
    var warning: String? = nil

    mutating func markAudio() {
        lastAudioAt = Date()
    }

    mutating func markCaption() {
        lastCaptionAt = Date()
    }
}
