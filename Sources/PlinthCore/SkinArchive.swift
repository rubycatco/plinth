import Compression
import Foundation
import UniformTypeIdentifiers

/// A `.plinthskin` file: a skin folder in a zip archive, to share a skin as
/// one file. Plinth installs one when it is opened, dropped on the fish, or
/// added with Add Skins…, and on the Mac exports a skin of your own as one.
public enum SkinArchive {
    public static let type = UTType(exportedAs: "dev.rubycat.plinth.skin", conformingTo: .zip)

    public enum Failure: Error {
        case unreadable, noSkin, link
    }

    /// More than any skin needs: the largest built-in skin is under half a
    /// megabyte. An archive that would unpack to more is refused, so one that
    /// inflates without end fills neither memory nor disk.
    private static let largest = 64 << 20

    /// Unpack `archive` into `scratch`, a new empty folder, and return the
    /// skin folder in it: the archive's top level, or its one folder (as
    /// `ditto -c -k --keepParent` and Finder's Compress make it).
    public static func unpack(_ archive: URL, into scratch: URL) throws -> URL {
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        // An archive is hardly larger than the files it holds, so one larger
        // than a skin may be, with room for its headers, is refused unread.
        guard let length = try? archive.resourceValues(forKeys: [.fileSizeKey]).fileSize, length <= largest + (1 << 20),
              let zip = try? Data(contentsOf: archive) else { throw Failure.unreadable }
        try zip.withUnsafeBytes { try extract($0, into: scratch) }
        if hasIdle(scratch) { return scratch }
        let folders = ((try? FileManager.default.contentsOfDirectory(at: scratch, includingPropertiesForKeys: nil)) ?? [])
            .filter(\.hasDirectoryPath)
        guard folders.count == 1, hasIdle(folders[0]) else { throw Failure.noSkin }
        return folders[0]
    }

    private static func hasIdle(_ folder: URL) -> Bool {
        FileManager.default.fileExists(atPath: folder.appending(path: "idle.png").path)
    }

    /// Write out the files and folders in `zip`, stored or deflated, as ditto,
    /// Finder and other zip tools write them. Compression inflates them on
    /// every Apple platform. Their sizes and checksums are read from the
    /// archive's directory, which comes after them, so a file written before
    /// its size was known reads too.
    private static func extract(_ zip: UnsafeRawBufferPointer, into folder: URL) throws {
        func bytes(_ at: Int, _ count: Int) throws -> UnsafeRawBufferPointer {
            guard at >= 0, count >= 0, at <= zip.count - count else { throw Failure.unreadable }
            return UnsafeRawBufferPointer(rebasing: zip[at ..< at + count])
        }
        func int(_ at: Int, _ size: Int) throws -> Int {
            try bytes(at, size).reversed().reduce(0) { $0 << 8 | Int($1) }
        }
        // The archive ends with where its directory is, then a comment of up to
        // 64 KB, which may hold something that looks like it.
        func directory(after end: Int) -> Bool {
            (try? int(end, 4) == 0x0605_4B50 && int(int(end + 16, 4), 4) == 0x0201_4B50) ?? false
        }
        var end = zip.count - 22
        while !directory(after: end) {
            guard end > 0, end > zip.count - 22 - 0xFFFF else { throw Failure.unreadable }
            end -= 1
        }
        let count = try int(end + 10, 2)
        var at = try int(end + 16, 4), total = 0, read = 0
        for _ in 0 ..< count {
            guard try int(at, 4) == 0x0201_4B50 else { throw Failure.unreadable }
            // Made on Unix or macOS, the upper half of the attributes is the file's mode.
            let unix = try [3, 19].contains(int(at + 5, 1)), mode = try int(at + 38, 4) >> 16
            let flags = try int(at + 8, 2), method = try int(at + 10, 2), crc = try int(at + 16, 4)
            let packed = try int(at + 20, 4), size = try int(at + 24, 4), header = try int(at + 42, 4)
            let nameLength = try int(at + 28, 2), more = try int(at + 30, 2) + int(at + 32, 2)
            let name = try String(decoding: bytes(at + 46, nameLength), as: UTF8.self)
            at += 46 + nameLength + more
            // A link could point anywhere on the Mac, so an archive with one is refused.
            if unix && (mode & 0o170000) == 0o120000 { throw Failure.link }
            // Neither ditto nor this reads an encrypted file, or one compressed
            // other than by deflate.
            guard flags & 1 == 0, method == 8 || (method == 0 && packed == size) else { throw Failure.unreadable }
            // As with ditto, a path that leads out of the folder stays in it.
            let path = name.split(separator: "/").reduce(into: [String]()) { path, part in
                if part == ".." { _ = path.popLast() } else if part != "." { path.append(String(part)) }
            }
            // Finder keeps resource forks and extended attributes in __MACOSX; a skin needs neither.
            if path.isEmpty || path[0] == "__MACOSX" { continue }
            let url = path.reduce(folder) { $0.appending(path: $1) }
            if name.hasSuffix("/") {
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
                continue
            }
            total += size
            // Each file's data has a place of its own in the archive. Files
            // listed over the same data would inflate it again and again, so
            // together they may read no more than the archive holds.
            read += packed
            guard total <= largest, read <= zip.count, try int(header, 4) == 0x0403_4B50 else { throw Failure.unreadable }
            // The file's own header, then its data.
            let data = try bytes(header + 30 + int(header + 26, 2) + int(header + 28, 2), packed)
            let file = method == 0 ? [UInt8](data) : inflate(data, to: size)
            guard file.count == size, crc32(file) == crc else { throw Failure.unreadable }
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(file).write(to: url)
        }
    }

    /// Raw DEFLATE data, as zip keeps it, inflated to at most `size` bytes.
    private static func inflate(_ packed: UnsafeRawBufferPointer, to size: Int) -> [UInt8] {
        guard size > 0, packed.count > 0 else { return [] }
        var out = [UInt8](repeating: 0, count: size)
        let count = out.withUnsafeMutableBufferPointer { out in
            packed.withMemoryRebound(to: UInt8.self) { packed in
                compression_decode_buffer(out.baseAddress!, size, packed.baseAddress!, packed.count, nil, COMPRESSION_ZLIB)
            }
        }
        return Array(out[..<count])
    }

    private static let crcTable: [UInt32] = (0 ..< 256).map { n in
        (0 ..< 8).reduce(UInt32(n)) { c, _ in c & 1 == 0 ? c >> 1 : 0xEDB8_8320 ^ (c >> 1) }
    }

    /// The CRC-32 a zip archive keeps for each file, to tell a damaged one.
    private static func crc32(_ bytes: [UInt8]) -> Int {
        Int(~bytes.reduce(~UInt32(0)) { crc, byte in crcTable[Int(UInt8(truncatingIfNeeded: crc) ^ byte)] ^ (crc >> 8) })
    }
}
