import AppKit
import Foundation
import FoundationModels
import Observation

/// What the on-device model produces for one item.
@Generable
struct RemovalImpact: Equatable {
    @Guide(description: "One plain sentence saying what this data is and what uses it.")
    var summary: String

    @Guide(description: "Two to four short, concrete effects on the developer's work, e.g. slower next build, a download needed, no offline installs, a tool that must be restarted. Don't repeat how to get it back.", .count(2...4))
    var consequences: [String]

    @Guide(description: "One sentence on how the data comes back (command or automatic) and roughly how long that takes.")
    var regeneration: String
}

enum ExplanationState {
    /// Streaming from the model. Fields fill in as they're generated.
    case generating(RemovalImpact.PartiallyGenerated?)
    case generated(RemovalImpact)
    /// The model isn't available or failed; the built-in description is shown.
    case fallback(reason: String)
}

/// Facts about an item that help the model be specific. Gathered on the main actor, passed to the prompt.
struct ImpactContext: Equatable, Sendable {
    var lockfiles: [String] = []
    var runningTools: [String] = []
}

@Observable
@MainActor
final class ImpactExplainer {
    private(set) var states: [ScanItem.ID: ExplanationState] = [:]
    private var tasks: [ScanItem.ID: Task<Void, Never>] = [:]

    /// Replaced in tests.
    var availability: () -> SystemLanguageModel.Availability = { SystemLanguageModel.default.availability }
    var runningBundleIDs: () -> Set<String> = {
        Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
    }

    static let instructions = """
    You explain to a software developer what happens if a specific cache or build folder on their Mac \
    is moved to the Trash. Be brief, concrete and factual. Use only the facts provided and well-known \
    behaviour of the named tool; don't invent file names, versions or numbers. \
    The folder goes to the Trash, so it can be put back until the Trash is emptied. Never say data is \
    lost permanently unless the facts say it can't be regenerated. Files listed as kept are outside \
    the folder and are not affected. Don't tell the user whether to delete it and don't repeat the \
    risk level back. Write in second person ("you").
    """

    func state(for item: ScanItem) -> ExplanationState? { states[item.id] }

    /// Starts an explanation unless one is cached or already running.
    func explain(_ item: ScanItem) {
        switch states[item.id] {
        case .generated?, .generating?: return
        case .fallback?, nil: break
        }

        if case .unavailable(let reason) = availability() {
            states[item.id] = .fallback(reason: Self.describe(reason))
            return
        }

        let prompt = Self.prompt(for: item, context: context(for: item))
        states[item.id] = .generating(nil)
        tasks[item.id] = Task { [weak self] in
            do {
                let session = LanguageModelSession(instructions: Self.instructions)
                let stream = session.streamResponse(to: prompt, generating: RemovalImpact.self)
                for try await snapshot in stream {
                    self?.states[item.id] = .generating(snapshot.content)
                }
                let response = try await stream.collect()
                self?.states[item.id] = .generated(response.content)
            } catch is CancellationError {
                self?.states[item.id] = nil
            } catch {
                self?.states[item.id] = .fallback(reason: "The on-device model couldn't explain this item.")
            }
            self?.tasks[item.id] = nil
        }
    }

    // MARK: - Prompt

    func context(for item: ScanItem) -> ImpactContext {
        var context = ImpactContext()
        if item.rule.artifactPattern != nil {
            let projectDir = item.url.deletingLastPathComponent()
            let names = Set((try? FileManager.default.contentsOfDirectory(atPath: projectDir.path)) ?? [])
            context.lockfiles = Self.knownLockfiles.filter(names.contains)
        }
        let running = runningBundleIDs()
        if running.contains("com.apple.dt.Xcode") { context.runningTools.append("Xcode") }
        if running.contains(where: { $0.hasPrefix("com.google.android.studio") }) { context.runningTools.append("Android Studio") }
        return context
    }

    static let knownLockfiles = [
        "package-lock.json", "yarn.lock", "pnpm-lock.yaml", "bun.lockb", "bun.lock",
        "Podfile.lock", "Package.resolved", "gradle.lockfile",
    ]

    static func prompt(for item: ScanItem, context: ImpactContext, now: Date = .now) -> String {
        var lines = [
            "Folder: \(item.url.tildePath)",
            "What it is: \(item.rule.name) — \(item.rule.summary)",
            "Category: \(item.rule.category.title)",
            "Size: \(item.size.fileSize)",
            "How it comes back: \(item.rule.regenerateHint)",
        ]
        if let project = item.projectName { lines.append("Project: \(project)") }
        if let modified = item.lastModified {
            let days = Int(now.timeIntervalSince(modified) / 86_400)
            lines.append("Last modified: \(days) days ago")
        }
        if item.rule.artifactPattern != nil {
            lines.append(context.lockfiles.isEmpty
                ? "Lockfile: none found next to this folder, so a reinstall may pick newer dependency versions"
                : "Kept (outside this folder, not removed): \(context.lockfiles.joined(separator: ", ")) — lets the exact same dependency versions be reinstalled")
        }
        if item.rule.risk == .caution {
            lines.append("Note: this may contain data that can't be regenerated.")
        }
        if !context.runningTools.isEmpty {
            lines.append("Currently running: \(context.runningTools.joined(separator: ", "))")
        }
        return "Explain the consequences of moving this folder to the Trash.\n\n" + lines.joined(separator: "\n")
    }

    static func describe(_ reason: SystemLanguageModel.Availability.UnavailableReason) -> String {
        switch reason {
        case .deviceNotEligible: "This Mac doesn't support Apple Intelligence."
        case .appleIntelligenceNotEnabled: "Apple Intelligence is turned off in System Settings."
        case .modelNotReady: "The on-device model is still downloading."
        @unknown default: "The on-device model isn't available."
        }
    }
}
