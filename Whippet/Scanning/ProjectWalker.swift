import Foundation

/// A removable directory found on disk, before it's measured.
struct ScanCandidate: Sendable, Hashable {
    let url: URL
    let rule: CleanupRule
    let projectName: String?
}

/// Walks project folders looking for directories that match project rules.
///
/// - Never follows symbolic links.
/// - Doesn't descend into matched artifacts, `node_modules`, `.git`, packages (`.app`, `.xcodeproj`),
///   or hidden folders that no rule needs.
struct ProjectWalker: Sendable {
    let rules: [CleanupRule]
    let exclusions: [URL]
    var maxDepth: Int = 12

    /// Directory names that are never descended into, even when they don't match a rule.
    private static let neverDescend: Set<String> = [".git", "node_modules", "Pods", "DerivedData", ".Trash"]

    private var projectRules: [(CleanupRule, ArtifactPattern)] {
        rules.compactMap { rule in rule.artifactPattern.map { (rule, $0) } }
    }

    /// Hidden directory names that have to be descended into, e.g. `.angular` for `.angular/cache`.
    private var hiddenPassThrough: Set<String> {
        Set(projectRules.flatMap { $0.1.intermediatePath.filter { $0.hasPrefix(".") } })
    }

    func findArtifacts(in roots: [URL]) throws -> [ScanCandidate] {
        var results: [ScanCandidate] = []
        let excluded = exclusions.map { Self.canonicalPath($0) }
        let passThrough = hiddenPassThrough
        let patterns = projectRules

        for root in roots {
            guard isRealDirectory(root) else { continue }
            let root = URL(fileURLWithPath: Self.canonicalPath(root), isDirectory: true)

            var stack: [(URL, Int)] = [(root, 0)]
            while let (dir, depth) = stack.popLast() {
                try Task.checkCancellation()

                // Child URLs are built from the canonical parent so paths stay comparable with exclusions.
                guard let childNames = try? FileManager.default.contentsOfDirectory(atPath: dir.path) else { continue }
                let names = Set(childNames)
                let children = childNames.sorted().map { dir.appendingPathComponent($0) }

                for child in children {
                    guard let values = try? child.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .isPackageKey]),
                          values.isDirectory == true,
                          values.isSymbolicLink != true
                    else { continue }

                    let path = child.path
                    if excluded.contains(where: { path == $0 || path.hasPrefix($0 + "/") }) { continue }

                    if let rule = match(child, parentNames: names, patterns: patterns) {
                        let anchor = anchorDirectory(for: child, pattern: rule.artifactPattern!)
                        results.append(ScanCandidate(url: child, rule: rule, projectName: projectName(for: anchor, root: root)))
                        continue
                    }

                    let name = child.lastPathComponent
                    if Self.neverDescend.contains(name) { continue }
                    if name.hasPrefix("."), !passThrough.contains(name) { continue }
                    if values.isPackage == true { continue }
                    if depth + 1 < maxDepth { stack.append((child, depth + 1)) }
                }
            }
        }
        return results
    }

    // MARK: - Matching

    private func match(_ dir: URL, parentNames: Set<String>, patterns: [(CleanupRule, ArtifactPattern)]) -> CleanupRule? {
        let name = dir.lastPathComponent
        for (rule, pattern) in patterns where pattern.directoryName == name {
            // Check the intermediate path, e.g. `.angular` in `.angular/cache`.
            var parent = dir.deletingLastPathComponent()
            var intermediateOK = true
            for expected in pattern.intermediatePath.reversed() {
                if parent.lastPathComponent != expected { intermediateOK = false; break }
                parent = parent.deletingLastPathComponent()
            }
            guard intermediateOK else { continue }

            let anchorNames = pattern.intermediatePath.isEmpty ? parentNames : directoryNames(in: parent)
            if markersPresent(pattern.markers, in: anchorNames) { return rule }
        }
        return nil
    }

    private func markersPresent(_ markers: [String], in names: Set<String>) -> Bool {
        markers.contains { marker in
            if marker.hasPrefix("*") {
                let suffix = String(marker.dropFirst())
                return names.contains { $0.hasSuffix(suffix) }
            }
            return names.contains(marker)
        }
    }

    private func directoryNames(in dir: URL) -> Set<String> {
        Set((try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? [])
    }

    private func anchorDirectory(for artifact: URL, pattern: ArtifactPattern) -> URL {
        var url = artifact.deletingLastPathComponent()
        for _ in pattern.intermediatePath { url = url.deletingLastPathComponent() }
        return url
    }

    /// Resolves symlinks (including `/var` → `/private/var`) so paths can be compared by prefix.
    static func canonicalPath(_ url: URL) -> String {
        guard let resolved = realpath(url.path, nil) else { return url.standardizedFileURL.path }
        defer { free(resolved) }
        return String(cString: resolved)
    }

    private func isRealDirectory(_ url: URL) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]) else { return false }
        return values.isDirectory == true && values.isSymbolicLink != true
    }

    // MARK: - Project name

    /// The `name` from the nearest `package.json` at or above `anchor` (up to `root`),
    /// otherwise the anchor folder's name. Folders like `ios`/`android` use their parent's name.
    func projectName(for anchor: URL, root: URL) -> String? {
        var dir = anchor
        let rootPath = root.path
        while dir.path.hasPrefix(rootPath) {
            if let name = packageJSONName(in: dir) { return name }
            if dir.path == rootPath { break }
            dir = dir.deletingLastPathComponent()
        }
        let platformFolders: Set<String> = ["ios", "android", "app", "macos", "web"]
        var named = anchor
        while platformFolders.contains(named.lastPathComponent.lowercased()), named.path != rootPath {
            named = named.deletingLastPathComponent()
        }
        return named.lastPathComponent
    }

    private func packageJSONName(in dir: URL) -> String? {
        let url = dir.appendingPathComponent("package.json")
        guard let data = try? Data(contentsOf: url),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let name = object["name"] as? String, !name.isEmpty
        else { return nil }
        return name
    }
}
