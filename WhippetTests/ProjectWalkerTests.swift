import Foundation
import Testing
@testable import Whippet

struct ProjectWalkerTests {
    private let walker = ProjectWalker(rules: RuleCatalog.all.filter(\.isEnabledByDefault), exclusions: [])

    private func found(_ fixture: Fixture, walker: ProjectWalker? = nil) throws -> [String: String] {
        let results = try (walker ?? self.walker).findArtifacts(in: [fixture.root])
        let prefix = ProjectWalker.canonicalPath(fixture.root) + "/"
        return Dictionary(results.map {
            let path = $0.url.path
            return (path.hasPrefix(prefix) ? String(path.dropFirst(prefix.count)) : path, $0.rule.id)
        }, uniquingKeysWith: { first, second in "\(first)+\(second)" })
    }

    @Test func nodeModulesNextToPackageJSONMatches() throws {
        let f = try Fixture()
        try f.file("web/package.json", contents: #"{"name":"my-web"}"#)
        try f.file("web/node_modules/react/index.js")

        let results = try walker.findArtifacts(in: [f.root])
        #expect(results.count == 1)
        #expect(results.first?.rule.id == "js.nodeModules")
        #expect(results.first?.projectName == "my-web")
    }

    @Test func orphanNodeModulesIsIgnored() throws {
        let f = try Fixture()
        try f.file("random/node_modules/thing/index.js")
        #expect(try found(f).isEmpty)
    }

    @Test func doesNotDescendIntoMatchedArtifacts() throws {
        let f = try Fixture()
        try f.file("app/package.json")
        try f.file("app/node_modules/lib/package.json")
        try f.file("app/node_modules/lib/node_modules/dep/index.js")
        #expect(try found(f) == ["app/node_modules": "js.nodeModules"])
    }

    @Test func symlinksAreNotFollowed() throws {
        let f = try Fixture()
        let outside = try Fixture()
        try outside.file("proj/package.json")
        try outside.file("proj/node_modules/x/index.js")
        try f.symlink("linked", to: outside.url("proj"))
        // A symlinked artifact next to a real marker is also skipped.
        try f.file("real/package.json")
        try f.symlink("real/node_modules", to: outside.url("proj/node_modules"))

        #expect(try found(f).isEmpty)
    }

    @Test func exclusionsAreRespected() throws {
        let f = try Fixture()
        try f.file("keep/package.json")
        try f.dir("keep/node_modules")
        try f.file("skip/package.json")
        try f.dir("skip/node_modules")

        let walker = ProjectWalker(rules: RuleCatalog.all, exclusions: [f.url("skip")])
        #expect(try found(f, walker: walker) == ["keep/node_modules": "js.nodeModules"])
    }

    @Test func reactNativeProjectArtifacts() throws {
        let f = try Fixture()
        try f.file("rn/package.json", contents: #"{"name":"CoolApp"}"#)
        try f.dir("rn/node_modules")
        try f.dir("rn/.expo")
        try f.file("rn/ios/Podfile")
        try f.dir("rn/ios/CoolApp.xcodeproj")
        try f.dir("rn/ios/Pods")
        try f.dir("rn/ios/build")
        try f.file("rn/android/settings.gradle")
        try f.dir("rn/android/.gradle")
        try f.file("rn/android/app/build.gradle")
        try f.dir("rn/android/app/build")
        try f.dir("rn/android/app/.cxx")

        #expect(try found(f) == [
            "rn/node_modules": "js.nodeModules",
            "rn/.expo": "rn.expo",
            "rn/ios/Pods": "rn.pods",
            "rn/ios/build": "xcode.projectBuild",
            "rn/android/.gradle": "android.projectGradle",
            "rn/android/app/build": "android.moduleBuild",
            "rn/android/app/.cxx": "android.cxx",
        ])

        let pods = try walker.findArtifacts(in: [f.root]).first { $0.rule.id == "rn.pods" }
        #expect(pods?.projectName == "CoolApp")
    }

    @Test func intermediatePathAndHiddenFolders() throws {
        let f = try Fixture()
        try f.file("ng/angular.json")
        try f.file("ng/package.json")
        try f.dir("ng/.angular/cache/19.0.0")
        try f.dir("ng/.idea/node_modules") // hidden folders are not descended into
        try f.dir("ng/.angular/other")

        #expect(try found(f) == ["ng/.angular/cache": "js.angularCache"])
    }

    @Test func disabledRulesAreNotMatched() throws {
        let f = try Fixture()
        try f.file("site/package.json")
        try f.dir("site/dist")
        #expect(try found(f).isEmpty)

        let all = ProjectWalker(rules: RuleCatalog.all, exclusions: [])
        #expect(try found(f, walker: all) == ["site/dist": "js.dist"])
    }

    @Test func projectNameFallsBackToFolderName() throws {
        let f = try Fixture()
        try f.file("NativeApp/NativeApp.xcodeproj/project.pbxproj")
        try f.dir("NativeApp/build")
        let result = try walker.findArtifacts(in: [f.root])
        #expect(result.first?.projectName == "NativeApp")
    }
}
