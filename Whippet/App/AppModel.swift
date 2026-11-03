import Foundation
import Observation

@Observable
@MainActor
final class AppModel {
    private(set) var items: [ScanItem] = []
    private(set) var isScanning = false
    private(set) var status: String?
    private(set) var lastScanDate: Date?

    /// Folders scanned for project artifacts. Hard-coded defaults until the Settings window exists.
    var projectRoots: [URL] = AppModel.suggestedProjectRoots()

    private var scanTask: Task<Void, Never>?

    var totalSize: Int64 { items.reduce(0) { $0 + $1.size } }

    func startScan() {
        scanTask?.cancel()
        items = []
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
                    insertSorted(item)
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

    private func insertSorted(_ item: ScanItem) {
        let index = items.firstIndex { $0.size < item.size } ?? items.endIndex
        items.insert(item, at: index)
    }

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
