import AppKit
import AVFoundation
import ScreenCaptureKit

enum DemoRecorderError: LocalizedError {
    case notAllowed, nothingToCapture

    var errorDescription: String? {
        switch self {
        case .notAllowed:
            "No permission to record the screen. Allow DevNotch in System Settings → Privacy & Security → Screen Recording and run it again."
        case .nothingToCapture:
            "Couldn't find the screen or DevNotch's windows to record."
        }
    }
}

final class DemoRecorder: NSObject, SCStreamOutput, @unchecked Sendable {
    var firstFrameTime: Double? {
        queue.sync { firstFrame }
    }

    /// Written by frames arriving on `queue`, so it's only ever touched there.
    private var firstFrame: Double?

    private var stream: SCStream?
    private var writer: AVAssetWriter?
    private var input: AVAssetWriterInput?
    private let queue = DispatchQueue(label: "dev.jrdan.devnotch.demo-recorder")

    @MainActor
    func start(region: CGRect, on screen: NSScreen, to url: URL) async throws {
        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        } catch {
            throw DemoRecorderError.notAllowed
        }
        let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
        guard let display = content.displays.first(where: { $0.displayID == displayID }),
              let app = content.applications.first(where: { $0.processID == ProcessInfo.processInfo.processIdentifier })
        else { throw DemoRecorderError.nothingToCapture }

        let scale = screen.backingScaleFactor
        let configuration = SCStreamConfiguration()
        configuration.sourceRect = region
        configuration.width = Int(region.width * scale)
        configuration.height = Int(region.height * scale)
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        configuration.showsCursor = false
        configuration.pixelFormat = kCVPixelFormatType_32BGRA
        configuration.queueDepth = 8

        try? FileManager.default.removeItem(at: url)
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: configuration.width,
            AVVideoHeightKey: configuration.height,
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 24_000_000],
        ])
        input.expectsMediaDataInRealTime = true
        writer.add(input)
        writer.startWriting()
        self.writer = writer
        self.input = input

        let stream = SCStream(
            filter: SCContentFilter(display: display, including: [app], exceptingWindows: []),
            configuration: configuration,
            delegate: nil
        )
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
        try await stream.startCapture()
        self.stream = stream
    }

    func stop() async throws {
        try await stream?.stopCapture()
        queue.sync {}
        input?.markAsFinished()
        await writer?.finishWriting()
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, sampleBuffer.isValid, Self.isNewFrame(sampleBuffer), let writer, let input else { return }
        if firstFrame == nil {
            writer.startSession(atSourceTime: sampleBuffer.presentationTimeStamp)
            firstFrame = sampleBuffer.presentationTimeStamp.seconds
        }
        if input.isReadyForMoreMediaData { input.append(sampleBuffer) }
    }

    /// ScreenCaptureKit also sends "nothing changed" buffers without pixels; only complete frames go in the file.
    private static func isNewFrame(_ buffer: CMSampleBuffer) -> Bool {
        guard let attachments = CMSampleBufferGetSampleAttachmentsArray(buffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let raw = attachments.first?[.status] as? Int
        else { return false }
        return SCFrameStatus(rawValue: raw) == .complete
    }
}
