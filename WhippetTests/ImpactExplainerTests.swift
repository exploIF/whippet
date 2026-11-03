import Foundation
import Testing
@testable import Whippet

@MainActor
struct ImpactExplainerTests {
    private func item(_ url: URL, rule id: String, project: String? = nil, daysOld: Double? = 10) -> ScanItem {
        ScanItem(
            url: url,
            rule: RuleCatalog.rule(id: id)!,
            projectName: project,
            size: 1_200_000_000,
            lastModified: daysOld.map { Date.now.addingTimeInterval(-$0 * 86_400) }
        )
    }

    @Test func promptIncludesRuleFactsAndContext() {
        let pods = item(URL(fileURLWithPath: "/Users/me/shop/ios/Pods"), rule: "rn.pods", project: "shop", daysOld: 41)
        let prompt = ImpactExplainer.prompt(
            for: pods,
            context: ImpactContext(lockfiles: ["Podfile.lock"], runningTools: ["Xcode"])
        )
        #expect(prompt.contains("CocoaPods Pods folder"))
        #expect(prompt.contains("Size: \(pods.size.fileSize)"))
        #expect(prompt.contains("Project: shop"))
        #expect(prompt.contains("41 days ago"))
        #expect(prompt.contains("Kept (outside this folder, not removed): Podfile.lock"))
        #expect(prompt.contains("Currently running: Xcode"))
        #expect(prompt.contains("pod install"))
    }

    @Test func promptMentionsMissingLockfileOnlyForProjectItems() {
        let nm = item(URL(fileURLWithPath: "/p/node_modules"), rule: "js.nodeModules")
        #expect(ImpactExplainer.prompt(for: nm, context: ImpactContext()).contains("Lockfile: none found"))

        let npm = item(URL(fileURLWithPath: "/Users/me/.npm/_cacache"), rule: "pm.npm")
        #expect(!ImpactExplainer.prompt(for: npm, context: ImpactContext()).contains("Lockfile"))
    }

    @Test func cautionItemsAreFlaggedInThePrompt() {
        let archives = item(URL(fileURLWithPath: "/a/Archives"), rule: "xcode.archives")
        #expect(ImpactExplainer.prompt(for: archives, context: ImpactContext()).contains("can't be regenerated"))
    }

    @Test func contextFindsLockfilesNextToTheArtifact() throws {
        let f = try Fixture()
        try f.file("app/package.json")
        try f.file("app/yarn.lock")
        try f.file("app/ios/Podfile.lock")
        try f.dir("app/node_modules")

        let explainer = ImpactExplainer()
        explainer.runningBundleIDs = { ["com.google.android.studio"] }
        let context = explainer.context(for: item(f.url("app/node_modules"), rule: "js.nodeModules"))
        #expect(context.lockfiles == ["yarn.lock"])
        #expect(context.runningTools == ["Android Studio"])
    }

    @Test func fallsBackWhenModelIsUnavailable() {
        let explainer = ImpactExplainer()
        explainer.availability = { .unavailable(.appleIntelligenceNotEnabled) }
        let nm = item(URL(fileURLWithPath: "/p/node_modules"), rule: "js.nodeModules")

        explainer.explain(nm)
        guard case .fallback(let reason) = explainer.state(for: nm) else {
            Issue.record("Expected fallback, got \(String(describing: explainer.state(for: nm)))")
            return
        }
        #expect(reason.contains("turned off"))
    }
}
