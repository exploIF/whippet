import Foundation
import Observation
import ServiceManagement

/// User preferences, saved in UserDefaults.
@Observable
@MainActor
final class SettingsStore {
    private enum Key {
        static let projectRoots = "projectRoots"
        static let exclusions = "exclusions"
        static let ruleOverrides = "ruleOverrides"
    }

    private let defaults: UserDefaults

    /// Folders scanned for project artifacts.
    var projectRoots: [URL] {
        didSet { save(projectRoots, for: Key.projectRoots) }
    }

    /// Folders that are never scanned or cleaned.
    var exclusions: [URL] {
        didSet { save(exclusions, for: Key.exclusions) }
    }

    /// Rule IDs whose on/off state differs from the rule's default.
    private(set) var ruleOverrides: [String: Bool] {
        didSet { defaults.set(ruleOverrides, forKey: Key.ruleOverrides) }
    }

    private(set) var launchAtLoginError: String?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let paths = defaults.stringArray(forKey: Key.projectRoots) {
            projectRoots = paths.map { URL(fileURLWithPath: $0, isDirectory: true) }
        } else {
            projectRoots = AppModel.suggestedProjectRoots()
        }
        exclusions = (defaults.stringArray(forKey: Key.exclusions) ?? [])
            .map { URL(fileURLWithPath: $0, isDirectory: true) }
        ruleOverrides = defaults.dictionary(forKey: Key.ruleOverrides) as? [String: Bool] ?? [:]
        refreshLaunchAtLogin()
    }

    // MARK: - Folders

    func addProjectRoots(_ urls: [URL]) {
        projectRoots = Self.merged(projectRoots, adding: urls)
    }

    func addExclusions(_ urls: [URL]) {
        exclusions = Self.merged(exclusions, adding: urls)
    }

    func resetProjectRoots() {
        projectRoots = AppModel.suggestedProjectRoots()
    }

    private static func merged(_ existing: [URL], adding urls: [URL]) -> [URL] {
        var result = existing
        let paths = Set(existing.map(\.standardizedFileURL.path))
        for url in urls where !paths.contains(url.standardizedFileURL.path) {
            result.append(url.standardizedFileURL)
        }
        return result
    }

    private func save(_ urls: [URL], for key: String) {
        defaults.set(urls.map(\.path), forKey: key)
    }

    // MARK: - Rules

    func isEnabled(_ rule: CleanupRule) -> Bool {
        ruleOverrides[rule.id] ?? rule.isEnabledByDefault
    }

    func setEnabled(_ rule: CleanupRule, _ enabled: Bool) {
        ruleOverrides[rule.id] = enabled == rule.isEnabledByDefault ? nil : enabled
    }

    func resetRules() {
        ruleOverrides = [:]
    }

    var enabledRules: [CleanupRule] { RuleCatalog.all.filter(isEnabled) }

    // MARK: - Launch at login

    private(set) var launchAtLogin = false
    private(set) var launchAtLoginNeedsApproval = false

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLoginError = nil
        } catch {
            launchAtLoginError = error.localizedDescription
        }
        refreshLaunchAtLogin()
    }

    /// Re-reads the login item state, which can also change in System Settings.
    func refreshLaunchAtLogin() {
        let status = SMAppService.mainApp.status
        launchAtLogin = status == .enabled
        launchAtLoginNeedsApproval = status == .requiresApproval
    }
}
