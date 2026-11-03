import Foundation
import Testing
@testable import Whippet

@MainActor
struct SettingsStoreTests {
    /// A throwaway defaults domain, so tests never touch the app's real settings.
    private func makeDefaults() -> UserDefaults {
        let name = "WhippetTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func foldersPersistAcrossInstances() {
        let defaults = makeDefaults()
        let store = SettingsStore(defaults: defaults)
        store.projectRoots = []
        store.addProjectRoots([URL(fileURLWithPath: "/tmp/a"), URL(fileURLWithPath: "/tmp/b")])
        store.addProjectRoots([URL(fileURLWithPath: "/tmp/a")]) // duplicate ignored
        store.addExclusions([URL(fileURLWithPath: "/tmp/a/vendor")])

        let reloaded = SettingsStore(defaults: defaults)
        #expect(reloaded.projectRoots.map(\.path) == ["/tmp/a", "/tmp/b"])
        #expect(reloaded.exclusions.map(\.path) == ["/tmp/a/vendor"])
    }

    @Test func emptyProjectListIsKept() {
        let defaults = makeDefaults()
        SettingsStore(defaults: defaults).projectRoots = []
        #expect(SettingsStore(defaults: defaults).projectRoots.isEmpty)
    }

    @Test func ruleOverridesPersistAndOnlyStoreDifferences() throws {
        let defaults = makeDefaults()
        let store = SettingsStore(defaults: defaults)
        let dist = try #require(RuleCatalog.rule(id: "js.dist"))       // off by default
        let npm = try #require(RuleCatalog.rule(id: "pm.npm"))         // on by default

        store.setEnabled(dist, true)
        store.setEnabled(npm, false)
        let reloaded = SettingsStore(defaults: defaults)
        #expect(reloaded.isEnabled(dist))
        #expect(!reloaded.isEnabled(npm))
        #expect(reloaded.enabledRules.contains(dist))
        #expect(!reloaded.enabledRules.contains(npm))

        reloaded.setEnabled(npm, true) // back to default → override removed
        #expect(reloaded.ruleOverrides == ["js.dist": true])

        reloaded.resetRules()
        #expect(SettingsStore(defaults: defaults).ruleOverrides.isEmpty)
    }

    @Test func scanUsesSettings() throws {
        let defaults = makeDefaults()
        let store = SettingsStore(defaults: defaults)
        store.setEnabled(try #require(RuleCatalog.rule(id: "js.nodeModules")), false)
        let model = AppModel(settings: store)
        #expect(!model.settings.enabledRules.contains { $0.id == "js.nodeModules" })
        #expect(model.projectRoots == store.projectRoots)
    }
}

struct ExclusionTests {
    @Test func globalCachesInsideExclusionsAreSkipped() throws {
        let f = try Fixture()
        try f.dir("home/.npm/_cacache")
        try f.dir("home/.gradle/caches")
        let scanner = ArtifactScanner(configuration: ScanConfiguration(
            rules: RuleCatalog.all,
            projectRoots: [],
            exclusions: [f.url("home/.gradle")],
            homeDirectory: f.url("home"),
            temporaryDirectory: f.url("tmp")
        ))
        #expect(scanner.globalCandidates().map(\.rule.id) == ["pm.npm"])
    }

    @Test func cleanerRefusesExcludedItemsAndTheirParents() throws {
        let f = try Fixture()
        try f.file("home/proj/package.json")
        try f.dir("home/proj/node_modules/keep-me")
        let rule = try #require(RuleCatalog.rule(id: "js.nodeModules"))
        let item = ScanItem(url: f.url("home/proj/node_modules"), rule: rule, projectName: nil, size: 1, lastModified: nil)

        let insideExcluded = Cleaner(allowedRoots: [f.url("home")], protectedPaths: [], excludedPaths: [f.url("home/proj")])
        #expect(throws: CleanupError.excluded) { try insideExcluded.validate(item) }

        let containsExcluded = Cleaner(allowedRoots: [f.url("home")], protectedPaths: [], excludedPaths: [f.url("home/proj/node_modules/keep-me")])
        #expect(throws: CleanupError.excluded) { try containsExcluded.validate(item) }
    }
}
