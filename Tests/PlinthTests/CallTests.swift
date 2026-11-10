import XCTest
@testable import Plinth
import PlinthCore

final class CallTests: XCTestCase {
    /// A call no one answers leaves the mallet on the wood, and the next
    /// knock of any kind lifts it. Silent, so no key or click answers it.
    @MainActor
    func testACallNoOneAnswersLeavesTheMalletOnTheWood() async throws {
        _ = NSApplication.shared
        let fish = Fish.shared
        let saved = (fish.volume, fish.autoKnock, fish.knockAsYouType, fish.bell)
        fish.volume = 0
        fish.autoKnock = false
        fish.knockAsYouType = false
        fish.bell = false
        defer { (fish.volume, fish.autoKnock, fish.knockAsYouType, fish.bell) = saved }

        fish.call()
        let knocks = Fish.callStrokes.reduce(0) { $0 + $1.gap }
        // Between the second knock and the third, the mallet is up.
        try await Task.sleep(for: .seconds(knocks - 1))
        XCTAssertFalse(fish.malletRests)
        XCTAssertFalse(fish.swing.holds)
        try await Task.sleep(for: .seconds(1 + Swing.impactDelay + 0.3))
        XCTAssertTrue(fish.malletRests, "The call's last knock leaves the mallet on the wood")
        // Once the call is over it is still there.
        try await Task.sleep(for: .seconds(Fish.callRest + 0.3))
        XCTAssertTrue(fish.malletRests, "A call no one answered leaves it there")

        // A knock that isn't by hand lifts it too, and rises from the wood.
        fish.knock(byHand: false)
        XCTAssertFalse(fish.malletRests)
        XCTAssertTrue(fish.swing.rises)
        XCTAssertFalse(fish.swing.holds)
        try await Task.sleep(for: .seconds(Swing.impactDelay + 0.2))
        XCTAssertFalse(fish.malletRests)
        // And the knock after that starts from where a mallet usually hangs.
        fish.knock(byHand: false)
        XCTAssertFalse(fish.swing.rises)
        try await Task.sleep(for: .seconds(Swing.impactDelay + 0.2))
    }
}
