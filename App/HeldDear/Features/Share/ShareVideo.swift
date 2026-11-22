import AVFoundation
import SwiftUI
import UIKit

/// Renders the share image and its moving version on the phone (no network): a 1080-pixel-wide still, and a
/// 6-second H.264 video for Stories, frame by frame from ShareCardView.
@MainActor
enum ShareRender {
    static let pixelWidth: CGFloat = 1080

    static func still(_ content: ShareCardContent, shape: ShareCardView.Shape) -> UIImage? {
        let renderer = ImageRenderer(content: ShareCardView(content: content, shape: shape))
        renderer.scale = pixelWidth / 390
        return renderer.uiImage
    }

    /// Writes the moving version to a temporary .mp4 and returns its address. `progress` reports 0 to 1.
    static func video(_ content: ShareCardContent, shape: ShareCardView.Shape, fps: Int = 30,
                      progress: @escaping (Double) -> Void) async throws -> URL {
        try await video(height: shape.height, duration: ShareCardLayout.duration, fps: fps, progress: progress) { t in
            ShareCardView(content: content, shape: shape, time: t)
        }
    }

    /// Any card laid out 390 points wide, as a video: `frame` draws the card at each moment.
    static func video<V: View>(height: CGFloat, duration: Double, fps: Int = 30, progress: @escaping (Double) -> Void,
                               frame: @escaping (Double) -> V) async throws -> URL {
        let scale = pixelWidth / 390
        let size = CGSize(width: pixelWidth, height: (height * scale / 2).rounded(.down) * 2)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("held-dear-\(UUID().uuidString).mp4")
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width), AVVideoHeightKey: Int(size.height)
        ])
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: Int(size.width), kCVPixelBufferHeightKey as String: Int(size.height)
        ])
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        let frames = Int(duration * Double(fps))
        for i in 0...frames {
            let t = Double(i) / Double(fps)
            let renderer = ImageRenderer(content: frame(t))
            renderer.scale = scale
            guard let cg = renderer.cgImage, let buffer = pixelBuffer(from: cg, size: size, pool: adaptor.pixelBufferPool) else { continue }
            while !input.isReadyForMoreMediaData { try await Task.sleep(nanoseconds: 5_000_000) }
            adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(i), timescale: CMTimeScale(fps)))
            progress(Double(i) / Double(max(1, frames)))
            if i % 6 == 0 { await Task.yield() }
        }
        input.markAsFinished()
        await writer.finishWriting()
        if writer.status != .completed { throw writer.error ?? CocoaError(.fileWriteUnknown) }
        return url
    }

    private static func pixelBuffer(from image: CGImage, size: CGSize, pool: CVPixelBufferPool?) -> CVPixelBuffer? {
        var buffer: CVPixelBuffer?
        if let pool { CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer) }
        if buffer == nil {
            CVPixelBufferCreate(nil, Int(size.width), Int(size.height), kCVPixelFormatType_32ARGB, nil, &buffer)
        }
        guard let buffer else { return nil }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let ctx = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: Int(size.width), height: Int(size.height),
                                  bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) else { return nil }
        ctx.draw(image, in: CGRect(origin: .zero, size: size))
        return buffer
    }
}
