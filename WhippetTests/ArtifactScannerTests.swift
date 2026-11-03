import Foundation
import Testing
@testable import Whippet

struct ArtifactScannerTests {
    private func scanner(_ f: Fixture, roots: [URL] = []) -> ArtifactScanner {
        ArtifactScanner(configuration: ScanConfiguration(
            rules: RuleCatalog.all.filter(\.isEnabledByDefault),
            projectRoots: roots,
            homeDirectory: f.url("home"),
            temporaryDirectory: f.url("tmp")
        ))
    }

    @Test func ruleIDsAreUnique() {
        let ids = RuleCatalog.all.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test func expandsHomeTmpAndWildcards() throws {
        let f = try Fixture()
        try f.dir("home/Library/Developer/Xcode/DerivedData")
        try f.dir("tmp/metro-cache")
        try f.dir("tmp/metro-file-map-abc")
        try f.dir("tmp/unrelated")
        try f.file("tmp/metro-a-file") // files are ignored

        let s = scanner(f)
        #expect(s.expand("~/Library/Developer/Xcode/DerivedData") == [f.url("home/Library/Developer/Xcode/DerivedData")])
        #expect(s.expand("$TMPDIR/metro-*").map(\.lastPathComponent) == ["metro-cache", "metro-file-map-abc"])
        #expect(s.expand("~/does/not/exist").isEmpty)
    }

    @Test func globalCandidatesOnlyIncludeExistingPaths() throws {
        let f = try Fixture()
        try f.dir("home/.gradle/caches")
        try f.dir("home/.npm/_cacache")

        let ids = Set(scanner(f).globalCandidates().map(\.rule.id))
        #expect(ids == ["android.gradleCaches", "pm.npm"])
    }

    @Test func deduplicationDropsNestedCandidates() {
        let rule = RuleCatalog.all[0]
        let c = { (p: String) in ScanCandidate(url: URL(fileURLWithPath: p), rule: rule, projectName: nil) }
        let result = ArtifactScanner.deduplicated([c("/a/b"), c("/a/b/c"), c("/a/b"), c("/a/bc")])
        #expect(result.map(\.url.path) == ["/a/b", "/a/bc"])
    }

    @Test func sizeCalculatorSumsFilesRecursively() throws {
        let f = try Fixture()
        try f.file("data/one.bin", bytes: 10_000)
        try f.file("data/sub/two.bin", bytes: 20_000)
        try f.file("data/sub/deeper/three.bin", bytes: 30_000)

        let measurement = try #require(SizeCalculator.measure(f.url("data")))
        #expect(measurement.size >= 60_000)
        #expect(measurement.size < 60_000 + 3 * 64 * 1024) // allocation rounds up per file
        #expect(measurement.lastModified != nil)
    }

    @Test func sizeCalculatorDoesNotFollowSymlinks() throws {
        let f = try Fixture()
        try f.file("big/file.bin", bytes: 500_000)
        try f.dir("small")
        try f.symlink("small/link", to: f.url("big"))

        let measurement = try #require(SizeCalculator.measure(f.url("small")))
        #expect(measurement.size < 100_000)
    }

    @Test func fullScanStreamsMeasuredItems() async throws {
        let f = try Fixture()
        try f.file("home/Library/Developer/Xcode/DerivedData/App-abc/Build/x.o", bytes: 50_000)
        try f.file("projects/web/package.json")
        try f.file("projects/web/node_modules/lib/index.js", bytes: 20_000)

        var items: [ScanItem] = []
        var finished = false
        for await event in scanner(f, roots: [f.url("projects")]).scan() {
            switch event {
            case .item(let item): items.append(item)
            case .finished: finished = true
            case .status: break
            }
        }

        #expect(finished)
        #expect(Set(items.map(\.rule.id)) == ["xcode.derivedData", "js.nodeModules"])
        #expect(items.allSatisfy { $0.size > 0 })
    }
}
