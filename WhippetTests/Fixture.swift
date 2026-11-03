import Foundation

/// A temporary directory tree for tests. Deleted when the fixture is deinitialised.
final class Fixture {
    let root: URL

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("WhippetTests-\(UUID().uuidString)", isDirectory: true)
            .resolvingSymlinksInPath()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: root)
    }

    func url(_ path: String) -> URL { root.appendingPathComponent(path) }

    /// Creates a file, with intermediate directories.
    @discardableResult
    func file(_ path: String, contents: String = "", bytes: Int? = nil) throws -> URL {
        let url = url(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = bytes.map { Data(repeating: 0x61, count: $0) } ?? Data(contents.utf8)
        try data.write(to: url)
        return url
    }

    @discardableResult
    func dir(_ path: String) throws -> URL {
        let url = url(path)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func symlink(_ path: String, to destination: URL) throws {
        try FileManager.default.createSymbolicLink(at: url(path), withDestinationURL: destination)
    }
}
