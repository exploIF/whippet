import Foundation
import Synchronization
import Testing
@testable import Whippet

struct CleanerTests {
    /// Records "trashed" URLs and removes them, instead of touching the real Trash.
    final class FakeTrash: Sendable {
        let moved = Mutex<[String]>([])
        func move(_ url: URL) throws {
            try FileManager.default.removeItem(at: url)
            moved.withLock { $0.append(url.lastPathComponent) }
        }
    }

    private func item(_ url: URL, rule id: String, size: Int64 = 100) -> ScanItem {
        ScanItem(url: url, rule: RuleCatalog.rule(id: id)!, projectName: nil, size: size, lastModified: nil)
    }

    private func cleaner(_ f: Fixture, trash: FakeTrash, projectRoots: [URL] = []) -> Cleaner {
        Cleaner(
            allowedRoots: [f.url("home")],
            protectedPaths: [f.url("home")] + projectRoots,
            moveToTrash: { try trash.move($0) }
        )
    }

    @Test func trashesValidItemsAndReportsSize() async throws {
        let f = try Fixture()
        try f.file("home/proj/package.json")
        try f.file("home/proj/node_modules/x/index.js")
        try f.dir("home/Library/Developer/Xcode/DerivedData")
        let trash = FakeTrash()

        let report = await cleaner(f, trash: trash).clean([
            item(f.url("home/proj/node_modules"), rule: "js.nodeModules", size: 300),
            item(f.url("home/Library/Developer/Xcode/DerivedData"), rule: "xcode.derivedData", size: 200),
        ])

        #expect(report.failures.isEmpty)
        #expect(report.freedSize == 500)
        #expect(trash.moved.withLock { $0 } == ["node_modules", "DerivedData"])
        #expect(!FileManager.default.fileExists(atPath: f.url("home/proj/node_modules").path))
        #expect(FileManager.default.fileExists(atPath: f.url("home/proj/package.json").path))
    }

    @Test func refusesMissingItems() throws {
        let f = try Fixture()
        #expect(throws: CleanupError.missing) {
            try cleaner(f, trash: FakeTrash()).validate(item(f.url("home/gone/node_modules"), rule: "js.nodeModules"))
        }
    }

    @Test func refusesSymlinks() throws {
        let f = try Fixture()
        try f.dir("home/real")
        try f.dir("home/proj")
        try f.symlink("home/proj/node_modules", to: f.url("home/real"))
        #expect(throws: CleanupError.symlink) {
            try cleaner(f, trash: FakeTrash()).validate(item(f.url("home/proj/node_modules"), rule: "js.nodeModules"))
        }
    }

    @Test func refusesItemsOutsideAllowedRoots() throws {
        let f = try Fixture()
        try f.dir("elsewhere/node_modules")
        #expect(throws: CleanupError.outsideAllowedLocations) {
            try cleaner(f, trash: FakeTrash()).validate(item(f.url("elsewhere/node_modules"), rule: "js.nodeModules"))
        }
    }

    @Test func refusesProtectedFoldersAndTheirParents() throws {
        let f = try Fixture()
        try f.dir("home/Projects/build/app")
        let c = cleaner(f, trash: FakeTrash(), projectRoots: [f.url("home/Projects/build/app")])
        // "build" matches the rule name but contains a project root.
        #expect(throws: CleanupError.protectedLocation) {
            try c.validate(item(f.url("home/Projects/build"), rule: "android.moduleBuild"))
        }
    }

    @Test func refusesNamesThatDontMatchTheRule() throws {
        let f = try Fixture()
        try f.dir("home/proj/src")
        #expect(throws: CleanupError.doesNotMatchRule) {
            try cleaner(f, trash: FakeTrash()).validate(item(f.url("home/proj/src"), rule: "js.nodeModules"))
        }
    }

    @Test func globalWildcardRulesMatchByPattern() {
        let metro = RuleCatalog.rule(id: "rn.metroCache")!
        #expect(Cleaner.nameMatchesRule("metro-cache", rule: metro))
        #expect(!Cleaner.nameMatchesRule("other", rule: metro))
        #expect(Cleaner.nameMatchesRule("DerivedData", rule: RuleCatalog.rule(id: "xcode.derivedData")!))
    }

    @Test func failuresDontStopTheRest() async throws {
        let f = try Fixture()
        try f.dir("home/a/node_modules")
        let trash = FakeTrash()
        let report = await cleaner(f, trash: trash).clean([
            item(f.url("home/missing/node_modules"), rule: "js.nodeModules"),
            item(f.url("home/a/node_modules"), rule: "js.nodeModules"),
        ])
        #expect(report.failures.map(\.error) == [.missing])
        #expect(report.trashed.count == 1)
    }
}

@MainActor
struct CleanupFlowTests {
    @Test func cleanupRemovesTrashedItemsFromResults() async throws {
        let f = try Fixture()
        try f.dir("home/p/node_modules")
        let trash = CleanerTests.FakeTrash()
        let model = AppModel()
        model.makeCleaner = { _ in
            Cleaner(allowedRoots: [f.url("home")], protectedPaths: [], moveToTrash: { try trash.move($0) })
        }
        let kept = ScanItem(url: f.url("home/q/node_modules"), rule: RuleCatalog.rule(id: "js.nodeModules")!,
                            projectName: nil, size: 5, lastModified: nil)
        let target = ScanItem(url: f.url("home/p/node_modules"), rule: RuleCatalog.rule(id: "js.nodeModules")!,
                              projectName: nil, size: 10, lastModified: nil)
        model.ingest(kept)
        model.ingest(target)
        model.setSelected(target, true)

        model.reviewCleanup()
        #expect(model.screen == .confirm)
        #expect(model.pendingCleanup.map(\.id) == [target.id])

        await model.performCleanup()
        #expect(model.screen == .report)
        #expect(model.lastReport?.trashed.count == 1)
        #expect(model.items.map(\.id) == [kept.id])
        #expect(model.selection.isEmpty)
    }

    @Test func warnsWhenXcodeIsRunning() {
        let model = AppModel()
        model.runningBundleIDs = { ["com.apple.dt.Xcode"] }
        let derived = ScanItem(url: URL(fileURLWithPath: "/tmp/DerivedData"), rule: RuleCatalog.rule(id: "xcode.derivedData")!,
                               projectName: nil, size: 1, lastModified: nil)
        model.ingest(derived)
        model.setSelected(derived, true)
        model.reviewCleanup()
        #expect(model.runningToolWarnings.count == 1)
    }
}
