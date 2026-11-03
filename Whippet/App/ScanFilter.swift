import Foundation

enum AgeFilter: Int, CaseIterable, Identifiable, Sendable {
    case any = 0
    case week = 7
    case month = 30
    case quarter = 90

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .any: "Any age"
        case .week: "Older than 7 days"
        case .month: "Older than 30 days"
        case .quarter: "Older than 90 days"
        }
    }
}

enum SizeFilter: Int64, CaseIterable, Identifiable, Sendable {
    case any = 0
    case tenMB = 10_000_000
    case hundredMB = 100_000_000
    case oneGB = 1_000_000_000

    var id: Int64 { rawValue }

    var title: String {
        switch self {
        case .any: "Any size"
        case .tenMB: "10 MB or more"
        case .hundredMB: "100 MB or more"
        case .oneGB: "1 GB or more"
        }
    }
}

struct ScanFilter: Equatable, Sendable {
    var age: AgeFilter = .any
    var minimumSize: SizeFilter = .any

    var isActive: Bool { age != .any || minimumSize != .any }

    /// Items with an unknown age are hidden by any age filter, so only items
    /// known to be old are offered.
    func matches(_ item: ScanItem, now: Date = .now) -> Bool {
        guard item.size >= minimumSize.rawValue else { return false }
        guard age != .any else { return true }
        guard let modified = item.lastModified else { return false }
        return now.timeIntervalSince(modified) >= Double(age.rawValue) * 86_400
    }
}
