import Foundation

/// A measured, removable item.
struct ScanItem: Identifiable, Sendable, Hashable {
    let url: URL
    let rule: CleanupRule
    let projectName: String?
    let size: Int64
    let lastModified: Date?

    var id: String { url.path }
}

enum ScanEvent: Sendable {
    case status(String)
    case item(ScanItem)
    case finished
}

struct ScanConfiguration: Sendable {
    var rules: [CleanupRule]
    var projectRoots: [URL]
    var exclusions: [URL] = []
    var homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    var temporaryDirectory: URL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    /// How many items are measured in parallel.
    var concurrency: Int = 4
}

/// Finds removable items for the configured rules and measures them.
struct ArtifactScanner: Sendable {
    let configuration: ScanConfiguration

    /// Streams results as they're measured. Cancelling the consuming task stops the scan.
    func scan() -> AsyncStream<ScanEvent> {
        AsyncStream { continuation in
            let task = Task.detached(priority: .utility) {
                await run(continuation)
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func run(_ continuation: AsyncStream<ScanEvent>.Continuation) async {
        continuation.yield(.status("Looking for caches…"))
        var candidates = globalCandidates()

        if !configuration.projectRoots.isEmpty {
            continuation.yield(.status("Scanning project folders…"))
            let walker = ProjectWalker(rules: configuration.rules, exclusions: configuration.exclusions)
            guard let found = try? walker.findArtifacts(in: configuration.projectRoots) else { return }
            candidates += found
        }
        candidates = Self.deduplicated(candidates)
        guard !Task.isCancelled else { return }

        continuation.yield(.status("Measuring \(candidates.count) items…"))
        await withTaskGroup(of: ScanItem?.self) { group in
            var pending = candidates.makeIterator()
            for _ in 0..<max(1, configuration.concurrency) {
                guard let next = pending.next() else { break }
                group.addTask { Self.measure(next) }
            }
            for await item in group {
                if let item { continuation.yield(.item(item)) }
                if Task.isCancelled { group.cancelAll(); return }
                if let next = pending.next() {
                    group.addTask { Self.measure(next) }
                }
            }
        }
        if !Task.isCancelled { continuation.yield(.finished) }
    }

    // MARK: - Global locations

    func globalCandidates() -> [ScanCandidate] {
        configuration.rules.flatMap { rule -> [ScanCandidate] in
            guard let pattern = rule.globalPath else { return [] }
            return expand(pattern).map { ScanCandidate(url: $0, rule: rule, projectName: nil) }
        }
    }

    /// Expands `~` and `$TMPDIR`, then resolves `*` wildcards in the last component.
    /// Only existing, non-symlink directories are returned.
    func expand(_ pattern: String) -> [URL] {
        var path = pattern
        if path == "~" || path.hasPrefix("~/") {
            path = configuration.homeDirectory.path + path.dropFirst()
        }
        if path.hasPrefix("$TMPDIR") {
            let tmp = configuration.temporaryDirectory.path
            path = (tmp.hasSuffix("/") ? String(tmp.dropLast()) : tmp) + path.dropFirst("$TMPDIR".count)
        }

        let url = URL(fileURLWithPath: path)
        let last = url.lastPathComponent
        let urls: [URL]
        if last.contains("*") {
            let parent = url.deletingLastPathComponent()
            let names = (try? FileManager.default.contentsOfDirectory(atPath: parent.path)) ?? []
            urls = names.sorted()
                .filter { fnmatch(last, $0, 0) == 0 }
                .map { parent.appendingPathComponent($0) }
        } else {
            urls = [url]
        }
        return urls.filter(Self.isRealDirectory)
    }

    // MARK: - Helpers

    private static func measure(_ candidate: ScanCandidate) -> ScanItem? {
        guard let measurement = SizeCalculator.measure(candidate.url) else { return nil }
        return ScanItem(
            url: candidate.url,
            rule: candidate.rule,
            projectName: candidate.projectName,
            size: measurement.size,
            lastModified: measurement.lastModified
        )
    }

    /// Removes duplicate paths and anything nested inside another candidate.
    static func deduplicated(_ candidates: [ScanCandidate]) -> [ScanCandidate] {
        var seen = Set<String>()
        let unique = candidates.filter { seen.insert($0.url.standardizedFileURL.path).inserted }
        let paths = unique.map { $0.url.standardizedFileURL.path }
        return unique.enumerated().filter { index, candidate in
            let path = paths[index]
            return !paths.enumerated().contains { other, otherPath in
                other != index && path.hasPrefix(otherPath + "/")
            }
        }.map(\.element)
    }

    private static func isRealDirectory(_ url: URL) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]) else { return false }
        return values.isDirectory == true && values.isSymbolicLink != true
    }
}
