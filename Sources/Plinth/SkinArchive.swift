import Foundation
import PlinthCore

extension SkinArchive {
    /// Write the skin folder `skin` to `archive`, with ditto, which ships with
    /// every Mac and writes the zip archives Finder makes.
    static func pack(_ skin: URL, to archive: URL) -> Bool {
        try? FileManager.default.removeItem(at: archive)
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/ditto")
        process.arguments = ["-c", "-k", "--keepParent", "--norsrc", "--noextattr", skin.path, archive.path]
        do { try process.run() } catch { return false }
        process.waitUntilExit()
        return process.terminationStatus == 0
    }
}
