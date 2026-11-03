import Foundation
import Observation
import AppKit
import SwiftUI

struct CategoryGroup: Identifiable {
    let category: CleanupCategory
    let items: [ScanItem]
    var id: CleanupCategory { category }
    var totalSize: Int64 { items.reduce(0) { $0 + $1.size } }
}

enum Screen: Equatable {
    case results
    case confirm
    case cleaning(done: Int, total: Int)
    case report
}

@Observable
@MainActor
final class AppModel {
    private(set) var items: [ScanItem] = []
    private(set) var isScanning = false
    private(set) var status: String?
    private(set) var lastScanDate: Date?

    var filter = ScanFilter()
    /// IDs of selected items. Hidden (filtered out) items are never acted on, even if selected.
    var selection: Set<ScanItem.ID> = []
    var expandedCategories: Set<CleanupCategory> = []

    /// Folders scanned for project artifacts. Hard-coded defaults until the Settings window exists.
    var projectRoots: [URL] = AppModel.suggestedProjectRoots()

    private(set) var screen: Screen = .results
    private(set) var lastReport: CleanupReport?
    /// Items shown on the confirmation screen, captured when it opens.
    private(set) var pendingCleanup: [ScanItem] = []

    private var scanTask: Task<Void, Never>?
    /// Replaced in tests so nothing is moved to the real Trash.
    var makeCleaner: @MainActor (_ projectRoots: [URL]) -> Cleaner = { Cleaner.standard(projectRoots: $0) }
    /// Returns bundle IDs of running apps. Replaced in tests.
    var runningBundleIDs: @MainActor () -> Set<String> = {
        Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
    }

    // MARK: - Derived state

    var visibleItems: [ScanItem] {
        let now = Date.now
        return items.filter { filter.matches($0, now: now) }
    }

    var hiddenCount: Int { items.count - visibleItems.count }

    var groups: [CategoryGroup] {
        Dictionary(grouping: visibleItems, by: \.rule.category)
            .map { CategoryGroup(category: $0.key, items: $0.value) }
            .sorted { $0.totalSize > $1.totalSize }
    }

    var visibleSize: Int64 { visibleItems.reduce(0) { $0 + $1.size } }

    var selectedItems: [ScanItem] { visibleItems.filter { selection.contains($0.id) } }

    var selectedSize: Int64 { selectedItems.reduce(0) { $0 + $1.size } }

    // MARK: - Selection

    func isSelected(_ item: ScanItem) -> Bool { selection.contains(item.id) }

    func setSelected(_ item: ScanItem, _ selected: Bool) {
        if selected { selection.insert(item.id) } else { selection.remove(item.id) }
    }

    func selectionBinding(for item: ScanItem) -> Binding<Bool> {
        Binding(
            get: { self.selection.contains(item.id) },
            set: { self.setSelected(item, $0) }
        )
    }

    func toggleExpanded(_ category: CleanupCategory) {
        if expandedCategories.contains(category) {
            expandedCategories.remove(category)
        } else {
            expandedCategories.insert(category)
        }
    }

    // MARK: - Cleanup

    func reviewCleanup() {
        pendingCleanup = selectedItems
        guard !pendingCleanup.isEmpty, !isScanning else { return }
        screen = .confirm
    }

    func cancelCleanup() {
        pendingCleanup = []
        screen = .results
    }

    var pendingSize: Int64 { pendingCleanup.reduce(0) { $0 + $1.size } }

    /// Warnings about tools that may be using the selected data right now.
    var runningToolWarnings: [String] {
        let running = runningBundleIDs()
        let categories = Set(pendingCleanup.map(\.rule.category))
        var warnings: [String] = []
        if categories.contains(.xcode), running.contains("com.apple.dt.Xcode") {
            warnings.append("Xcode is running. Quit it first so it doesn't recreate or lock files while they're moved.")
        }
        let androidStudio = running.contains { $0.hasPrefix("com.google.android.studio") }
        if categories.contains(.android), androidStudio {
            warnings.append("Android Studio is running. Quit it first; Gradle daemons may be using these caches.")
        }
        return warnings
    }

    func performCleanup() async {
        let items = pendingCleanup
        guard !items.isEmpty else { return }
        screen = .cleaning(done: 0, total: items.count)

        let cleaner = makeCleaner(projectRoots)
        let report = await Task.detached(priority: .userInitiated) {
            await cleaner.clean(items) { done in
                await MainActor.run { [weak self] in
                    self?.screen = .cleaning(done: done, total: items.count)
                }
            }
        }.value

        let removed = Set(report.trashed.map(\.id))
        self.items.removeAll { removed.contains($0.id) }
        selection.subtract(removed)
        pendingCleanup = []
        lastReport = report
        screen = .report
    }

    func dismissReport() {
        lastReport = nil
        screen = .results
    }

    // MARK: - Scanning

    func startScan() {
        scanTask?.cancel()
        screen = .results
        items = []
        selection = []
        isScanning = true
        status = nil

        let configuration = ScanConfiguration(
            rules: RuleCatalog.all.filter(\.isEnabledByDefault),
            projectRoots: projectRoots
        )
        let scanner = ArtifactScanner(configuration: configuration)

        scanTask = Task {
            for await event in scanner.scan() {
                switch event {
                case .status(let text):
                    status = text
                case .item(let item):
                    ingest(item)
                case .finished:
                    lastScanDate = .now
                }
            }
            isScanning = false
            status = nil
        }
    }

    func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
        status = nil
    }

    /// Adds a measured item, keeping items sorted by size. Nothing is selected automatically.
    func ingest(_ item: ScanItem) {
        let index = items.firstIndex { $0.size < item.size } ?? items.endIndex
        items.insert(item, at: index)
    }

    // MARK: - Defaults

    /// Common development folders that exist in the user's home folder.
    static func suggestedProjectRoots(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> [URL] {
        let names = [
            "Developer", "Projects", "projects", "WebstormProjects", "IdeaProjects",
            "AndroidStudioProjects", "StudioProjects", "code", "Code", "dev", "src",
            "repos", "Documents/GitHub",
        ]
        var seen = Set<String>()
        return names
            .map { home.appendingPathComponent($0, isDirectory: true) }
            .filter { url in
                var isDir: ObjCBool = false
                guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else { return false }
                // Case-insensitive file systems report both "code" and "Code"; keep one.
                let key = (url.resolvingSymlinksInPath().path as NSString).lowercased
                return seen.insert(key).inserted
            }
    }
}
