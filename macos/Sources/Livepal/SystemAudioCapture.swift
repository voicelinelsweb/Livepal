import AVFoundation
import CoreMedia
import Foundation
import ScreenCaptureKit

final class SystemAudioCapture: NSObject {
    private var stream: SCStream?
    private let output = AudioStreamOutput()

    func start(window: SCWindow, onPCM: @escaping @Sendable (AVAudioPCMBuffer) -> Void) async throws {
        try await stop()

        output.onPCM = onPCM

        let filter = SCContentFilter(desktopIndependentWindow: window)
        let config = SCStreamConfiguration()
        config.width = 960
        config.height = 540
        config.minimumFrameInterval = CMTime(value: 1, timescale: 15)
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = false
        config.capturesAudio = true
        // Note: `captureMicrophone` exists only on newer SDKs; omit so CI (macOS 14 runners) compiles.
        // Incoming-audio capture uses the window’s system audio stream, not the mic.
        config.excludesCurrentProcessAudio = true
        config.sampleRate = 48_000
        config.channelCount = 2

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
    }

    private static let videoQueue = DispatchQueue(label: "livepal.sc.video", qos: .userInitiated)
    private static let audioQueue = DispatchQueue(label: "livepal.sc.audio", qos: .userInitiated)
}

private final class AudioStreamOutput: NSObject, SCStreamOutput, SCStreamDelegate {
    var onPCM: (@Sendable (AVAudioPCMBuffer) -> Void)?

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
        guard outputType == .audio, sampleBuffer.isValid else { return }
        guard let pcm = Self.makePCM(from: sampleBuffer) else { return }
        onPCM?(pcm)
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        // Surface via SessionController if needed; keep lightweight here.
    }

    private static func makePCM(from buffer: CMSampleBuffer) -> AVAudioPCMBuffer? {
        var result: AVAudioPCMBuffer?
        try? buffer.withAudioBufferList { audioBufferList, blockBuffer in
            guard
                let description = buffer.formatDescription?.audioStreamBasicDescription,
                let format = AVAudioFormat(standardFormatWithSampleRate: description.mSampleRate, channels: AVAudioChannelCount(description.mChannelsPerFrame)),
                let pcm = AVAudioPCMBuffer(pcmFormat: format, bufferListNoCopy: audioBufferList.unsafePointer)
            else {
                return
            }
            result = pcm
        }
        return result
    }
}
