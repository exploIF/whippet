import Foundation
import Testing
@testable import Whippet

@MainActor
struct AppModelTests {
    private func item(_ path: String, rule id: String, size: Int64, daysOld: Double?) -> ScanItem {
        ScanItem(
            url: URL(fileURLWithPath: path),
            rule: RuleCatalog.rule(id: id)!,
            projectName: nil,
            size: size,
            lastModified: daysOld.map { Date.now.addingTimeInterval(-$0 * 86_400) }
        )
    }

    @Test func itemsStaySortedBySize() {
        let model = AppModel()
        model.ingest(item("/a", rule: "pm.npm", size: 10, daysOld: 1))
        model.ingest(item("/b", rule: "pm.npm", size: 30, daysOld: 1))
        model.ingest(item("/c", rule: "pm.npm", size: 20, daysOld: 1))
        #expect(model.items.map(\.size) == [30, 20, 10])
    }

    @Test func nothingIsPreselected() {
        let model = AppModel()
        model.ingest(item("/derived", rule: "xcode.derivedData", size: 1, daysOld: 1))
        model.ingest(item("/nm", rule: "js.nodeModules", size: 1, daysOld: 1))
        #expect(model.selection.isEmpty)
        #expect(model.selectedItems.isEmpty)
    }

    @Test func groupsAreSortedByTotalSize() {
        let model = AppModel()
        model.ingest(item("/x1", rule: "xcode.derivedData", size: 100, daysOld: 1))
        model.ingest(item("/j1", rule: "js.nodeModules", size: 80, daysOld: 1))
        model.ingest(item("/j2", rule: "js.nodeModules", size: 80, daysOld: 1))
        #expect(model.groups.map(\.category) == [.javascript, .xcode])
    }

    @Test func filtersHideItemsAndExcludeThemFromSelection() {
        let model = AppModel()
        model.ingest(item("/old", rule: "pm.npm", size: 500_000_000, daysOld: 40))
        model.ingest(item("/new", rule: "pm.yarn", size: 500_000_000, daysOld: 2))
        model.ingest(item("/tiny", rule: "pm.bun", size: 1_000, daysOld: 100))
        model.ingest(item("/unknown", rule: "pm.homebrew", size: 500_000_000, daysOld: nil))
        model.items.forEach { model.setSelected($0, true) }
        #expect(model.selectedItems.count == 4)

        model.filter.age = .month
        #expect(Set(model.visibleItems.map(\.url.path)) == ["/old", "/tiny"])

        model.filter.minimumSize = .hundredMB
        #expect(model.visibleItems.map(\.url.path) == ["/old"])
        #expect(model.selectedItems.map(\.url.path) == ["/old"])
        #expect(model.hiddenCount == 3)
    }

    @Test func selectionBindingReadsAndWrites() {
        let model = AppModel()
        let nm = item("/n1", rule: "js.nodeModules", size: 1, daysOld: 1)
        model.ingest(nm)
        let binding = model.selectionBinding(for: nm)
        #expect(binding.wrappedValue == false)
        binding.wrappedValue = true
        #expect(model.selection == ["/n1"])
        binding.wrappedValue = false
        #expect(model.selection.isEmpty)
    }
}
