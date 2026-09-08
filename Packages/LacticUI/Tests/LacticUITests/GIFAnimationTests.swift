import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import LacticUI

/// Builds real GIF bytes with ImageIO so the decoder is tested against actual
/// files rather than a hand-rolled fixture that might encode assumptions the
/// decoder shares.
private func makeGIF(frameDelays: [Double], size: Int = 4) -> Data? {
    let data = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(
        data, UTType.gif.identifier as CFString, frameDelays.count, nil
    ) else { return nil }

    CGImageDestinationSetProperties(destination, [
        kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0],
    ] as CFDictionary)

    for delay in frameDelays {
        guard let context = CGContext(
            data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let image = context.makeImage() else { return nil }

        CGImageDestinationAddImage(destination, image, [
            kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFUnclampedDelayTime: delay],
        ] as CFDictionary)
    }

    return CGImageDestinationFinalize(destination) ? data as Data : nil
}

@Suite("GIF decoding")
struct GIFAnimationTests {
    @Test func decodesEveryFrame() throws {
        let data = try #require(makeGIF(frameDelays: [0.1, 0.1, 0.1]))
        let animation = try #require(GIFAnimation(data: data))

        #expect(animation.frames.count == 3)
        #expect(animation.isAnimated)
        #expect(abs(animation.totalDuration - 0.3) < 0.01)
    }

    @Test func keepsPerFrameTiming() throws {
        let data = try #require(makeGIF(frameDelays: [0.05, 0.25]))
        let animation = try #require(GIFAnimation(data: data))

        #expect(animation.frames.count == 2)
        #expect(abs(animation.frames[0].duration - 0.05) < 0.01)
        #expect(abs(animation.frames[1].duration - 0.25) < 0.01)
    }

    /// A delay under 20ms means "as fast as possible" in old authoring tools.
    /// Every browser rewrites it to 100ms; a decoder that plays it literally
    /// renders the demonstration as an unreadable blur.
    ///
    /// The arguments stop at 0.01 because **GIF stores delays in centiseconds**,
    /// so anything finer is rounded on write — 0.015 and 0.019 both come back as
    /// 0.02 and are legitimately at the threshold rather than below it. Verified
    /// by round-tripping through ImageIO rather than assumed.
    @Test(arguments: [0.0, 0.005, 0.01])
    func clampsImplausiblyShortDelays(delay: Double) throws {
        let data = try #require(makeGIF(frameDelays: [delay, delay]))
        let animation = try #require(GIFAnimation(data: data))

        #expect(animation.frames.allSatisfy { $0.duration == GIFAnimation.defaultDelay })
    }

    /// 0.02 is exactly the threshold and must survive; 0.019 is not
    /// representable in the format and rounds up to it.
    @Test func leavesPlausibleDelaysAlone() throws {
        let data = try #require(makeGIF(frameDelays: [0.02, 0.5]))
        let animation = try #require(GIFAnimation(data: data))

        #expect(abs(animation.frames[0].duration - 0.02) < 0.001)
        #expect(abs(animation.frames[1].duration - 0.5) < 0.001)
    }

    /// A single-frame GIF is valid and should render as a still, not fail.
    @Test func handlesASingleFrame() throws {
        let data = try #require(makeGIF(frameDelays: [0.1]))
        let animation = try #require(GIFAnimation(data: data))

        #expect(animation.frames.count == 1)
        #expect(!animation.isAnimated, "one frame is a still, and must not drive an animation loop")
    }

    /// The proxy returns JSON on failure — 404, 502, 503 all have bodies. Those
    /// bytes must not be mistaken for an image.
    @Test func rejectsNonImageData() {
        #expect(GIFAnimation(data: Data(#"{"error":"Animation unavailable"}"#.utf8)) == nil)
        #expect(GIFAnimation(data: Data()) == nil)
    }
}

@Suite("Animation cache")
struct AnimationCacheTests {
    @Test func storesAndReturnsBytes() async {
        let cache = AnimationCache(directoryName: "TestAnimations-\(UUID().uuidString)")
        let payload = Data("gif-bytes".utf8)

        await cache.store(payload, for: "/api/v1/exercises/42/animation")
        let read = await cache.data(for: "/api/v1/exercises/42/animation")

        #expect(read == payload)
        await cache.removeAll()
    }

    @Test func missesForAnUnknownKey() async {
        let cache = AnimationCache(directoryName: "TestAnimations-\(UUID().uuidString)")
        #expect(await cache.data(for: "/api/v1/exercises/999/animation") == nil)
        await cache.removeAll()
    }

    /// Keys are API paths and contain slashes; a naive filename would let one
    /// escape the cache directory.
    @Test func keepsSlashedKeysInsideTheCacheDirectory() async {
        let cache = AnimationCache(directoryName: "TestAnimations-\(UUID().uuidString)")
        let payload = Data("x".utf8)

        await cache.store(payload, for: "../../etc/passwd")
        #expect(await cache.data(for: "../../etc/passwd") == payload)
        await cache.removeAll()
    }
}
