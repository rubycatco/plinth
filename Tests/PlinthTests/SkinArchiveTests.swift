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

    /// An archive larger than a skin may be is refused before it is read.
    /// Here a skin comes after 65 MB of nothing, as a self-extracting
    /// archive's files come after a program; after a kilobyte, it unpacks.
    func testRefusesAnArchiveTooLargeForASkin() throws {
        for (gap, unpacks) in [(1 << 10, true), (65 << 20, false)] {
            let archive = scratch.appending(path: "after-\(gap).plinthskin")
            // Nothing is written in the gap, so the file is sparse.
            XCTAssertTrue(FileManager.default.createFile(atPath: archive.path, contents: nil))
            let handle = try FileHandle(forWritingTo: archive)
            try handle.seek(toOffset: UInt64(gap))
            try handle.write(contentsOf: zipArchive([("skin/idle.png", 0o100644)], gap: gap))
            try handle.close()
            let out = scratch.appending(path: "unpacked-\(gap)")
            if unpacks {
                XCTAssertEqual(try SkinArchive.unpack(archive, into: out).lastPathComponent, "skin")
            } else {
                XCTAssertThrowsError(try SkinArchive.unpack(archive, into: out)) {
                    XCTAssertEqual($0 as? SkinArchive.Failure, .unreadable)
                }
            }
        }
    }

    /// Each file's data has a place of its own in an archive. A directory
    /// that lists the same data over and over, for it to be inflated again
    /// and again, is refused; listed once, it unpacks.
    func testRefusesFilesListedOverTheSameData() throws {
        let picture = Data((0 ..< 4096).map { UInt8(truncatingIfNeeded: $0 * 7) })
        for (listed, unpacks) in [(1, true), (10, false)] {
            let archive = scratch.appending(path: "listed-\(listed).plinthskin")
            try zipArchive([("skin/idle.png", 0o100644)], contents: picture, listed: listed).write(to: archive)
            let out = scratch.appending(path: "unpacked-\(listed)")
            if unpacks {
                let folder = try SkinArchive.unpack(archive, into: out)
                XCTAssertEqual(try Data(contentsOf: folder.appending(path: "idle.png")), picture)
            } else {
                XCTAssertThrowsError(try SkinArchive.unpack(archive, into: out)) {
                    XCTAssertEqual($0 as? SkinArchive.Failure, .unreadable)
                }
            }
        }
    }

    /// A zip archive of files made on Unix, each with its name and mode, all
    /// stored holding `contents`. It is to be written `gap` bytes into a file,
    /// and its directory lists each file `listed` times, always at its one copy.
    private func zipArchive(_ entries: [(name: String, mode: Int)], contents: Data = Data(), gap: Int = 0,
                            listed: Int = 1) -> Data {
        var files = Data(), directory = Data(), end = Data()
        func put(_ data: inout Data, _ fields: [(value: Int, size: Int)]) {
            for (value, size) in fields {
                for i in 0 ..< size { data.append(UInt8(truncatingIfNeeded: value >> (8 * i))) }
            }
        }
        // An empty file's checksum is 0, as is its size.
        let crc = crc32(contents), size = contents.count
        for (name, mode) in entries {
            let utf8 = Data(name.utf8)
            var listing = Data()
            put(&listing, [(0x0201_4B50, 4), (0x0314, 2), (10, 2), (0, 2), (0, 2), (0, 4), (crc, 4), (size, 4), (size, 4),
                           (utf8.count, 2), (0, 2), (0, 2), (0, 2), (0, 2), (mode << 16, 4), (gap + files.count, 4)])
            listing.append(utf8)
            for _ in 0 ..< listed { directory.append(listing) }
            put(&files, [(0x0403_4B50, 4), (10, 2), (0, 2), (0, 2), (0, 4), (crc, 4), (size, 4), (size, 4), (utf8.count, 2),
                         (0, 2)])
            files.append(utf8)
            files.append(contents)
        }
        let listings = entries.count * listed
        put(&end, [(0x0605_4B50, 4), (0, 2), (0, 2), (listings, 2), (listings, 2), (directory.count, 4),
                   (gap + files.count, 4), (0, 2)])
        return files + directory + end
    }

    /// The CRC-32 a zip archive keeps for each file.
    private func crc32(_ data: Data) -> Int {
        Int(~data.reduce(~UInt32(0)) { crc, byte in
            (0 ..< 8).reduce(crc ^ UInt32(byte)) { c, _ in c & 1 == 0 ? c >> 1 : 0xEDB8_8320 ^ (c >> 1) }
        })
    }
}
