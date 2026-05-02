import AVFoundation
import CoreMedia
import Foundation
import ScreenCaptureKit

final class SystemAudioCapture: NSObject {
    private var stream: SCStream?
    private let output = AudioStreamOutput()

    var onCaptureError: ((Error) -> Void)?

    func start(window: SCWindow, onPCM: @escaping @Sendable (AVAudioPCMBuffer) -> Void) async throws {
        try await stop()

        output.onPCM = onPCM
        output.onStreamError = { [weak self] error in
            self?.onCaptureError?(error)
        }

        let filter = SCContentFilter(desktopIndependentWindow: window)
        let config = SCStreamConfiguration()
        config.width = 960
        config.height = 540
        config.minimumFrameInterval = CMTime(value: 1, timescale: 15)
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = false
        config.capturesAudio = true
        config.excludesCurrentProcessAudio = true
        config.sampleRate = 48_000
        config.channelCount = 2
        config.queueDepth = 3

        let stream = SCStream(filter: filter, configuration: config, delegate: output)
        try stream.addStreamOutput(output, type: .screen, sampleHandlerQueue: Self.videoQueue)
        try stream.addStreamOutput(output, type: .audio, sampleHandlerQueue: Self.audioQueue)
        try await stream.startCapture()
        self.stream = stream
    }

    func stop() async throws {
        if let stream {
            try await stream.stopCapture()
        }
        stream = nil
        output.onPCM = nil
        output.onStreamError = nil
    }

    private static let videoQueue = DispatchQueue(label: "livepal.sc.video", qos: .userInitiated)
    private static let audioQueue = DispatchQueue(label: "livepal.sc.audio", qos: .userInitiated)
}

private final class AudioStreamOutput: NSObject, SCStreamOutput, SCStreamDelegate {
    var onPCM: (@Sendable (AVAudioPCMBuffer) -> Void)?
    var onStreamError: ((Error) -> Void)?

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
        guard outputType == .audio, sampleBuffer.isValid else { return }
        guard let pcm = Self.makePCM(from: sampleBuffer) else { return }
        onPCM?(pcm)
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        onStreamError?(error)
    }

    private static func makePCM(from buffer: CMSampleBuffer) -> AVAudioPCMBuffer? {
        var result: AVAudioPCMBuffer?
        try? buffer.withAudioBufferList { audioBufferList, _ in
            guard
                let description = buffer.formatDescription?.audioStreamBasicDescription,
                let format = AVAudioFormat(
                    standardFormatWithSampleRate: description.mSampleRate,
                    channels: AVAudioChannelCount(description.mChannelsPerFrame)
                ),
                let pcm = AVAudioPCMBuffer(pcmFormat: format, bufferListNoCopy: audioBufferList.unsafePointer)
            else { return }
            result = pcm
        }
        return result
    }
}
