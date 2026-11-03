import Foundation

struct SizeMeasurement: Sendable, Equatable {
    /// Bytes allocated on disk.
    var size: Int64
    /// Newest modification date among the directory and its subdirectories.
    ///
    /// File dates aren't used because package managers often reset them
    /// (npm sets every file to 1985), while directory dates reflect when
    /// something was installed or built.
    var lastModified: Date?
}

enum SizeCalculator {
    private static let keys: [URLResourceKey] = [
        .isDirectoryKey, .isSymbolicLinkKey,
        .totalFileAllocatedSizeKey, .fileAllocatedSizeKey,
        .contentModificationDateKey,
    ]

    /// Measures a file or directory without following symlinks.
    /// Returns `nil` if the task is cancelled while measuring.
    static func measure(_ url: URL) -> SizeMeasurement? {
        let fm = FileManager.default
        guard let rootValues = try? url.resourceValues(forKeys: Set(keys)) else {
            return SizeMeasurement(size: 0, lastModified: nil)
        }

        var total: Int64 = 0
        var newest = rootValues.contentModificationDate

        if rootValues.isDirectory != true || rootValues.isSymbolicLink == true {
            total = Int64(rootValues.totalFileAllocatedSize ?? rootValues.fileAllocatedSize ?? 0)
            return SizeMeasurement(size: total, lastModified: newest)
        }

        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: keys,
            options: [],
            errorHandler: { _, _ in true }
        ) else {
            return SizeMeasurement(size: 0, lastModified: newest)
        }

        var counter = 0
        for case let child as URL in enumerator {
            counter += 1
            if counter % 2048 == 0, Task.isCancelled { return nil }

            guard let values = try? child.resourceValues(forKeys: Set(keys)) else { continue }
            if values.isDirectory == true, values.isSymbolicLink != true {
                if let date = values.contentModificationDate, date > (newest ?? .distantPast) {
                    newest = date
                }
            } else {
                total += Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
            }
        }
        return SizeMeasurement(size: total, lastModified: newest)
    }
}
