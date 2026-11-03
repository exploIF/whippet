import Foundation

enum CleanupError: LocalizedError, Equatable {
    case missing
    case symlink
    case notADirectory
    case outsideAllowedLocations
    case protectedLocation
    case doesNotMatchRule
    case trashFailed(String)

    var errorDescription: String? {
        switch self {
        case .missing: "It no longer exists."
        case .symlink: "It's a symbolic link, so it was left alone."
        case .notADirectory: "It's no longer a folder."
        case .outsideAllowedLocations: "It's outside your home and temporary folders."
        case .protectedLocation: "It's a project folder or contains one."
        case .doesNotMatchRule: "Its name no longer matches the rule it was found by."
        case .trashFailed(let message): message
        }
    }
}

struct CleanupFailure: Identifiable, Sendable {
    let item: ScanItem
    let error: CleanupError
    var id: String { item.id }
}

struct CleanupReport: Sendable {
    var trashed: [ScanItem] = []
    var failures: [CleanupFailure] = []
    var freedSize: Int64 { trashed.reduce(0) { $0 + $1.size } }
}

/// Moves scanned items to the Trash after re-checking that each one is safe to remove.
struct Cleaner: Sendable {
    /// Items must be inside one of these folders.
    var allowedRoots: [URL]
    /// Never removed, and nothing that contains them is removed either (e.g. project roots).
    var protectedPaths: [URL]
    /// Moves a URL to the Trash. Replaced in tests.
    var moveToTrash: @Sendable (URL) throws -> Void = { url in
        try FileManager.default.trashItem(at: url, resultingItemURL: nil)
    }

    static func standard(projectRoots: [URL]) -> Cleaner {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let important = ["Desktop", "Documents", "Downloads", "Library", "Developer", ".gradle", ".npm", ".android"]
            .map { home.appendingPathComponent($0) }
        return Cleaner(
            allowedRoots: [home, tmp],
            protectedPaths: [home, tmp] + important + projectRoots
        )
    }

    /// Checks that an item can still be removed safely.
    func validate(_ item: ScanItem) throws(CleanupError) {
        let url = item.url
        guard let values = try? url.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey]) else {
            throw .missing
        }
        if values.isSymbolicLink == true { throw .symlink }
        if values.isDirectory != true { throw .notADirectory }

        let path = ProjectWalker.canonicalPath(url)
        let allowed = allowedRoots.map(ProjectWalker.canonicalPath)
        guard allowed.contains(where: { path.hasPrefix($0 + "/") }) else {
            throw .outsideAllowedLocations
        }

        // Refuse the protected folders themselves, and any folder that contains one.
        for protected in protectedPaths.map(ProjectWalker.canonicalPath) {
            if protected == path || protected.hasPrefix(path + "/") {
                throw .protectedLocation
            }
        }

        guard Self.nameMatchesRule(url.lastPathComponent, rule: item.rule) else {
            throw .doesNotMatchRule
        }
    }

    /// Validates and trashes items one at a time. Calls `progress` with the number processed so far.
    func clean(_ items: [ScanItem], progress: @Sendable (Int) async -> Void = { _ in }) async -> CleanupReport {
        var report = CleanupReport()
        for (index, item) in items.enumerated() {
            do {
                try validate(item)
                do {
                    try moveToTrash(item.url)
                } catch {
                    throw CleanupError.trashFailed(error.localizedDescription)
                }
                report.trashed.append(item)
            } catch let error as CleanupError {
                report.failures.append(CleanupFailure(item: item, error: error))
            } catch {
                report.failures.append(CleanupFailure(item: item, error: .trashFailed(error.localizedDescription)))
            }
            await progress(index + 1)
        }
        return report
    }

    static func nameMatchesRule(_ name: String, rule: CleanupRule) -> Bool {
        switch rule.location {
        case .project(let pattern):
            return name == pattern.directoryName
        case .global(let pattern):
            let last = (pattern as NSString).lastPathComponent
            return fnmatch(last, name, 0) == 0
        }
    }
}
