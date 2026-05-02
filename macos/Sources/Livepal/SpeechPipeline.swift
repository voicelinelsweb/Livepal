import AVFoundation
import Foundation
import Speech

private final class OneShotFlag: @unchecked Sendable {
    var consumed = false
}

@MainActor
final class SpeechPipeline {
    private let recognizer: SFSpeechRecognizer
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var converter: AVAudioConverter?
    private let targetFormat: AVAudioFormat
    private let preferOnDevice: Bool

    private var inflightBuffers = 0
    private let maxInflightBuffers = 6

    var onRuntimeError: ((Error) -> Void)?

    init(locale: Locale, preferOnDevice: Bool = true) throws {
        guard let recognizer = SFSpeechRecognizer(locale: locale) else {
            throw NSError(domain: "Livepal", code: 10, userInfo: [NSLocalizedDescriptionKey: "Speech recognizer unavailable for \(locale.identifier)"])
        }
        self.recognizer = recognizer
        self.preferOnDevice = preferOnDevice
        guard let targetFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false) else {
            throw NSError(domain: "Livepal", code: 11, userInfo: [NSLocalizedDescriptionKey: "Failed to build target audio format"])
        }
        self.targetFormat = targetFormat
    }

    func start(
        onPartial: @escaping (String) -> Void,
        onFinal: @escaping (String) -> Void
    ) {
        stop()

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = preferOnDevice && recognizer.supportsOnDeviceRecognition
        self.request = request

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            if let error {
                Task { @MainActor in
                    self?.onRuntimeError?(error)
                }
                return
            }
            guard let result else { return }
            let text = result.bestTranscription.formattedString
            if result.isFinal {
                Task { @MainActor in onFinal(text) }
            } else {
                Task { @MainActor in onPartial(text) }
            }
        }
    }

    func append(buffer: AVAudioPCMBuffer) {
        guard inflightBuffers < maxInflightBuffers else {
            return
        }
        inflightBuffers += 1
        defer { inflightBuffers = max(0, inflightBuffers - 1) }

        guard let converted = convert(buffer) else { return }
        request?.append(converted)
    }

    func stop() {
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
        converter = nil
        inflightBuffers = 0
    }

    private func convert(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        if converter == nil {
            converter = AVAudioConverter(from: buffer.format, to: targetFormat)
        }
        guard let converter else { return nil }

        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let outCapacity = max(32, AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 32)
        guard let out = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outCapacity) else { return nil }

        var error: NSError?
        let consumed = OneShotFlag()
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            if consumed.consumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            consumed.consumed = true
            outStatus.pointee = .haveData
            return buffer
        }

        converter.convert(to: out, error: &error, withInputFrom: inputBlock)
        if let error {
            onRuntimeError?(error)
            return nil
        }
        return out
    }
}
