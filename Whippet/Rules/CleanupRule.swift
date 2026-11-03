import Foundation

enum CleanupCategory: String, CaseIterable, Sendable, Identifiable {
    case xcode
    case android
    case reactNative
    case javascript
    case packageManagers

    var id: String { rawValue }

    var title: String {
        switch self {
        case .xcode: "Xcode & Swift"
        case .android: "Android & Gradle"
        case .reactNative: "React Native & CocoaPods"
        case .javascript: "JavaScript & Web"
        case .packageManagers: "Package Manager Caches"
        }
    }

    var systemImage: String {
        switch self {
        case .xcode: "hammer"
        case .android: "cube"
        case .reactNative: "atom"
        case .javascript: "curlybraces"
        case .packageManagers: "shippingbox"
        }
    }
}

enum CleanupRisk: Int, CaseIterable, Sendable, Comparable {
    /// Pure cache, rebuilt automatically with little cost.
    case safe
    /// Rebuilt automatically, but it can take a while or need a network download.
    case moderate
    /// May contain data that can't be regenerated.
    case caution

    static func < (lhs: CleanupRisk, rhs: CleanupRisk) -> Bool { lhs.rawValue < rhs.rawValue }

    var title: String {
        switch self {
        case .safe: "Safe"
        case .moderate: "Slow to rebuild"
        case .caution: "Caution"
        }
    }

    var explanation: String {
        switch self {
        case .safe: "A pure cache. It's recreated automatically with little cost."
        case .moderate: "Recreated automatically, but it can take a while or need a download."
        case .caution: "May contain data that can't be regenerated."
        }
    }
}

/// Describes a directory inside a project that can be removed, e.g. `node_modules` next to `package.json`.
struct ArtifactPattern: Sendable, Hashable {
    /// Name of the artifact directory, e.g. `node_modules`.
    var directoryName: String
    /// Directory names between the project directory and the artifact, outermost first.
    /// For `.angular/cache` this is `[".angular"]`.
    var intermediatePath: [String] = []
    /// Entries that must exist in the project directory for a match. At least one has to exist.
    /// A leading `*` matches by suffix, e.g. `*.xcodeproj`.
    var markers: [String]
}

struct CleanupRule: Identifiable, Sendable, Hashable {
    enum Location: Sendable, Hashable {
        /// A fixed location. Supports a leading `~`, `$TMPDIR`, and `*` wildcards in the last path component.
        case global(String)
        /// A directory found inside the user's project folders.
        case project(ArtifactPattern)
    }

    let id: String
    let category: CleanupCategory
    let name: String
    let location: Location
    let risk: CleanupRisk
    /// Plain description, used when the on-device model isn't available.
    let summary: String
    /// How the data comes back after removal.
    let regenerateHint: String
    var isEnabledByDefault: Bool = true

    var artifactPattern: ArtifactPattern? {
        if case .project(let pattern) = location { pattern } else { nil }
    }

    var globalPath: String? {
        if case .global(let path) = location { path } else { nil }
    }

    static func == (lhs: CleanupRule, rhs: CleanupRule) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
