import Foundation
@testable import Plinth
import PlinthCore
import XCTest

final class SkinArchiveTests: XCTestCase {
    private var scratch: URL!

    override func setUpWithError() throws {
        scratch = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: scratch)
    }

    /// Every built-in skin comes back byte for byte from the archive that
    /// Export as .plinthskin writes.
    func testUnpacksWhatExportWrites() throws {
        let skins = URL(filePath: #filePath).deletingLastPathComponent().appending(path: "../../App/Resources/Skins").standardized
        let names = try FileManager.default.contentsOfDirectory(atPath: skins.path).filter { !$0.hasPrefix(".") }
        XCTAssertEqual(names.count, 21)
        for name in names {
            let skin = skins.appending(path: name)
            let archive = scratch.appending(path: "\(name).plinthskin")
            XCTAssertTrue(SkinArchive.pack(skin, to: archive))
            let folder = try SkinArchive.unpack(archive, into: scratch.appending(path: "unpacked-\(name)"))
            XCTAssertEqual(folder.lastPathComponent, name)
            let files = try FileManager.default.contentsOfDirectory(atPath: skin.path).sorted()
            XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: folder.path).sorted(), files)
            for file in files {
                XCTAssertEqual(try Data(contentsOf: folder.appending(path: file)), try Data(contentsOf: skin.appending(path: file)),
                               "\(name)/\(file)")
            }
        }
    }

    /// As with ditto, an entry that would land outside the folder lands in
    /// it, and a link refuses the whole archive.
    func testKeepsEverythingInTheFolder() throws {
        let file = 0o100644, archive = scratch.appending(path: "skin.plinthskin")
        for (name, inside) in [("../escaped", "escaped"), ("skin/../../escaped", "escaped"),
                               ("/tmp/plinth-escaped", "tmp/plinth-escaped")] {
            let out = scratch.appending(path: UUID().uuidString)
            try zipArchive([("skin/idle.png", file), (name, file)]).write(to: archive)
            _ = try? SkinArchive.unpack(archive, into: out.appending(path: "unpacked"))
            XCTAssertTrue(FileManager.default.fileExists(atPath: out.appending(path: "unpacked/\(inside)").path), name)
            XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: out.path), ["unpacked"], name)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: "/tmp/plinth-escaped"))
        try zipArchive([("skin/idle.png", file), ("skin/mallet.png", 0o120777)]).write(to: archive)
        XCTAssertThrowsError(try SkinArchive.unpack(archive, into: scratch.appending(path: "linked"))) {
            XCTAssertEqual($0 as? SkinArchive.Failure, .link)
        }
    }

    /// A zip archive of empty files, each with its name and Unix mode.
    private func zipArchive(_ entries: [(name: String, mode: Int)]) -> Data {
        var files = Data(), directory = Data(), end = Data()
        func put(_ data: inout Data, _ fields: [(value: Int, size: Int)]) {
            for (value, size) in fields {
                for i in 0 ..< size { data.append(UInt8(truncatingIfNeeded: value >> (8 * i))) }
            }
        }
        for (name, mode) in entries {
            let utf8 = Data(name.utf8)
            // Made on Unix, stored, with no checksum or size, as an empty file has none.
            put(&directory, [(0x0201_4B50, 4), (0x0314, 2), (10, 2), (0, 2), (0, 2), (0, 4), (0, 4), (0, 4), (0, 4),
                             (utf8.count, 2), (0, 2), (0, 2), (0, 2), (0, 2), (mode << 16, 4), (files.count, 4)])
            directory.append(utf8)
            put(&files, [(0x0403_4B50, 4), (10, 2), (0, 2), (0, 2), (0, 4), (0, 4), (0, 4), (0, 4), (utf8.count, 2), (0, 2)])
            files.append(utf8)
        }
        put(&end, [(0x0605_4B50, 4), (0, 2), (0, 2), (entries.count, 2), (entries.count, 2), (directory.count, 4),
                   (files.count, 4), (0, 2)])
        return files + directory + end
    }
}
