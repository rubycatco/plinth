import Foundation
import PlinthCore
import XCTest

final class SkinTests: XCTestCase {
    private var scratch: URL!

    override func setUpWithError() throws {
        scratch = FileManager.default.temporaryDirectory.appending(path: "PlinthSkinTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: scratch)
    }

    /// A folder with an idle.png (not a real image; nothing here decodes it) and a skin.json.
    private func folder(_ path: String, json: String = "{}", marker: String = "idle") throws -> URL {
        let url = scratch.appending(path: path)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try Data(marker.utf8).write(to: url.appending(path: "idle.png"))
        try Data(json.utf8).write(to: url.appending(path: "skin.json"))
        return url
    }

    /// Frames that "decode" to their file's name, if the file is there.
    private func frame(_ url: URL) -> String? {
        var isFolder: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isFolder), !isFolder.boolValue else { return nil }
        return url.lastPathComponent
    }

    func testASkinIsNamedInTheLanguageShown() throws {
        let mug = try folder("mug", json: #"{ "name": "Mug", "names": { "zh-Hans": "马克杯" }, "voice": "ceramic" }"#)
        XCTAssertEqual(Skin.load(mug, language: "zh-Hans", image: frame)?.name, "马克杯")
        XCTAssertEqual(Skin.load(mug, language: "en", image: frame)?.name, "Mug")
        XCTAssertEqual(Skin.load(mug, language: "fr", image: frame)?.name, "Mug")
        XCTAssertEqual(Skin.load(mug, language: nil, image: frame)?.name, "Mug")
        XCTAssertEqual(Skin.load(mug, language: "zh-Hans", image: frame)?.voice, "ceramic")
        // Without `names`, as every skin made before it: the one name.
        let plain = try folder("plain", json: #"{ "name": "Plain" }"#)
        XCTAssertEqual(Skin.load(plain, language: "zh-Hans", image: frame)?.name, "Plain")
    }

    func testASkinThatMovedToTheGalleryStaysWithAFishThatWearsIt() throws {
        let retired = scratch.appending(path: "Retired"), skins = scratch.appending(path: "Skins")
        _ = try folder("Retired/mug", json: #"{ "name": "Mug" }"#)
        try FileManager.default.createDirectory(at: skins, withIntermediateDirectories: true)

        XCTAssertEqual(SkinOption.handOver("builtin/mug", from: retired, to: skins), "mug")
        XCTAssertEqual(try String(contentsOf: skins.appending(path: "mug/skin.json"), encoding: .utf8), #"{ "name": "Mug" }"#)
        XCTAssertTrue(FileManager.default.fileExists(atPath: skins.appending(path: "mug/idle.png").path))
        // The app's copy is left where it was.
        XCTAssertTrue(FileManager.default.fileExists(atPath: retired.appending(path: "mug/idle.png").path))
    }

    func testAHandoverLeavesASkinOfTheSameNameAlone() throws {
        let retired = scratch.appending(path: "Retired"), skins = scratch.appending(path: "Skins")
        _ = try folder("Retired/mug")
        _ = try folder("Skins/mug", marker: "theirs")

        XCTAssertEqual(SkinOption.handOver("builtin/mug", from: retired, to: skins), "mug")
        XCTAssertEqual(try String(contentsOf: skins.appending(path: "mug/idle.png"), encoding: .utf8), "theirs")
    }

    func testOnlyASkinThatMovedIsHandedOver() throws {
        let retired = scratch.appending(path: "Retired"), skins = scratch.appending(path: "Skins")
        _ = try folder("Retired/mug")
        _ = try folder("Elsewhere/secret")
        try FileManager.default.createDirectory(at: skins, withIntermediateDirectories: true)

        // The wooden fish, a skin that still ships, one of the fish's own, and ids that aren't a folder's name.
        for id in ["", "builtin/ink-fish", "mug", "mug.png", "builtin/", "builtin/../Elsewhere/secret", "builtin/.", "builtin/mug/idle.png"] {
            XCTAssertNil(SkinOption.handOver(id, from: retired, to: skins), id)
        }
        XCTAssertNil(SkinOption.handOver("builtin/mug", from: nil, to: skins))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: skins.path), [])
    }
}
