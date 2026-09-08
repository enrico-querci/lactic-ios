import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// A decoded animation: frames and how long each is shown.
///
/// Decoded with ImageIO rather than a third-party image library. Exercise
/// demonstrations are the only animated content in the app, the API guarantees
/// `image/gif` (its provider adapter rejects anything else outright), and
/// ImageIO already ships in the OS.
public struct GIFAnimation: @unchecked Sendable {
    public struct Frame {
        public let image: CGImage
        public let duration: TimeInterval
    }

    public let frames: [Frame]

    public var totalDuration: TimeInterval {
        frames.reduce(0) { $0 + $1.duration }
    }

    public var isAnimated: Bool {
        frames.count > 1
    }

    /// GIF delays below 20ms are a legacy of pre-2000 authoring tools that used
    /// 0 to mean "as fast as possible". Every browser silently rewrites them to
    /// 100ms, and a decoder that does not ends up playing a 10ms-per-frame
    /// animation as an unreadable blur.
    static let minimumDelay: TimeInterval = 0.02
    static let defaultDelay: TimeInterval = 0.1

    public init?(data: Data) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let count = CGImageSourceGetCount(source)
        guard count > 0 else { return nil }

        var frames: [Frame] = []
        frames.reserveCapacity(count)
        for index in 0 ..< count {
            guard let image = CGImageSourceCreateImageAtIndex(source, index, nil) else { continue }
            frames.append(Frame(image: image, duration: Self.delay(of: source, at: index)))
        }

        guard !frames.isEmpty else { return nil }
        self.frames = frames
    }

    static func delay(of source: CGImageSource, at index: Int) -> TimeInterval {
        guard
            let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
            let gif = properties[kCGImagePropertyGIFDictionary] as? [CFString: Any]
        else { return defaultDelay }

        // Unclamped is the value the file actually declares; the clamped one has
        // already had the viewer's own floor applied, so prefer unclamped and
        // apply our own.
        let unclamped = gif[kCGImagePropertyGIFUnclampedDelayTime] as? Double
        let clamped = gif[kCGImagePropertyGIFDelayTime] as? Double
        guard let declared = unclamped ?? clamped else { return defaultDelay }

        return declared < minimumDelay ? defaultDelay : declared
    }
}
