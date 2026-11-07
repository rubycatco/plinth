import SwiftUI
import XCTest
@testable import Plinth
import PlinthCore

final class ImpactTests: XCTestCase {
    @MainActor
    func testRapidKnocksKeepTheBurstWithinItsFullSize() async throws {
        _ = NSApplication.shared
        let fish = Fish.shared
        let saved = (fish.volume, fish.autoKnock, fish.knockAsYouType)
        fish.volume = 0
        fish.autoKnock = false
        fish.knockAsYouType = false
        defer {
            fish.volume = saved.0
            fish.autoKnock = saved.1
            fish.knockAsYouType = saved.2
        }

        // Isolate the burst so its rendered extent can be measured, without
        // depending on the bundled artwork or the mallet's position.
        let clear = NSImage(size: NSSize(width: 64, height: 64), flipped: false) { _ in true }
        let circle = NSImage(size: clear.size, flipped: false) { rect in
            NSColor.white.setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1)).fill()
            return true
        }
        let pack = SkinPack(idle: clear, mallet: clear, impact: circle)
        let side = 150
        let host = NSHostingView(rootView: WornFish(pack: pack, side: CGFloat(side)).environment(fish))
        host.sizingOptions = []
        let panel = NSPanel(contentRect: NSRect(x: 200, y: 200, width: side, height: side),
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.contentView = host
        panel.orderFrontRegardless()
        defer { panel.orderOut(nil) }
        try await Task.sleep(for: .milliseconds(100))

        // Let one knock finish, then interrupt successive bursts before they
        // finish growing. The skin contract caps even a full-strength burst
        // at 0.26 × 1.15 of the fish's side; rushed ones should be smaller.
        let knocks = [0.0, 0.7, 0.9, 1.1, 1.3, 1.5, 1.7, 1.9, 2.1, 2.3]
        let start = ProcessInfo.processInfo.systemUptime
        var next = 0, widest = 0
        var sawRapidBurst = false
        while ProcessInfo.processInfo.systemUptime - start < 3 {
            let elapsed = ProcessInfo.processInfo.systemUptime - start
            if next < knocks.count, elapsed >= knocks[next] {
                fish.knock(byHand: false)
                next += 1
            }
            host.layoutSubtreeIfNeeded()
            let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: bitmap)
            let image = try XCTUnwrap(bitmap.cgImage)
            // Normalize Retina and non-Retina snapshots to one pixel per point.
            var pixels = [UInt8](repeating: 0, count: side * side * 4)
            let context = try XCTUnwrap(CGContext(data: &pixels, width: side, height: side, bitsPerComponent: 8,
                                                 bytesPerRow: side * 4, space: CGColorSpaceCreateDeviceRGB(),
                                                 bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
            var left = side, right = -1
            for y in 0..<side {
                for x in 0..<side where pixels[(y * side + x) * 4 + 3] > 4 {
                    left = min(left, x)
                    right = max(right, x)
                }
            }
            widest = max(widest, right - left + 1)
            if elapsed > 1.5, right >= left { sawRapidBurst = true }
            try await Task.sleep(for: .milliseconds(12))
        }
        XCTAssertEqual(next, knocks.count, "The full rapid-knock sequence must run")
        XCTAssertGreaterThan(widest, 10, "The burst must actually render")
        XCTAssertTrue(sawRapidBurst, "Repeated knocks must still show their bursts")
        XCTAssertLessThanOrEqual(Double(widest), Double(side) * 0.26 * 1.15 + 2,
                                 "Repeated knocks must not send the burst outside its intended size")
    }
}
