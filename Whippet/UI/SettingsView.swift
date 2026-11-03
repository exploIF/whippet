import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    var body: some View {
        TabView {
            Tab("Folders", systemImage: "folder") { FoldersSettings() }
            Tab("Rules", systemImage: "checklist") { RulesSettings() }
            Tab("General", systemImage: "gearshape") { GeneralSettings() }
        }
        .frame(width: 520, height: 500)
    }
}

// MARK: - Folders

private struct FoldersSettings: View {
    @Environment(SettingsStore.self) private var settings
    @State private var picking: PickerTarget?

    private enum PickerTarget { case projects, exclusions }

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section {
                FolderList(urls: $settings.projectRoots, empty: "No project folders. Only global caches will be scanned.")
                HStack {
                    Button("Add Folder…") { picking = .projects }
                    Spacer()
                    Button("Use Suggested Folders") { settings.resetProjectRoots() }
                }
            } header: {
                Text("Project folders")
            } footer: {
                Text("Searched for build folders such as node_modules, Pods and Gradle build output.")
                    .foregroundStyle(.secondary)
            }

            Section {
                FolderList(urls: $settings.exclusions, empty: "No exclusions.")
                Button("Add Folder…") { picking = .exclusions }
            } header: {
                Text("Excluded folders")
            } footer: {
                Text("Never scanned or cleaned, including anything inside them.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .fileImporter(
            isPresented: Binding(get: { picking != nil }, set: { if !$0 { picking = nil } }),
            allowedContentTypes: [.folder],
            allowsMultipleSelection: true
        ) { result in
            guard case .success(let urls) = result else { return }
            switch picking {
            case .projects: settings.addProjectRoots(urls)
            case .exclusions: settings.addExclusions(urls)
            case nil: break
            }
            picking = nil
        }
    }
}

private struct FolderList: View {
    @Binding var urls: [URL]
    let empty: String

    var body: some View {
        if urls.isEmpty {
            Text(empty).foregroundStyle(.secondary)
        } else {
            ForEach(urls, id: \.path) { url in
                HStack {
                    Image(systemName: "folder.fill").foregroundStyle(.secondary)
                    Text(url.tildePath)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if !FileManager.default.fileExists(atPath: url.path) {
                        Text("Missing").font(.caption).foregroundStyle(.orange)
                    }
                    Spacer()
                    Button {
                        urls.removeAll { $0 == url }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .help("Remove")
                }
            }
        }
    }
}

// MARK: - Rules

private struct RulesSettings: View {
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        Form {
            ForEach(CleanupCategory.allCases) { category in
                Section {
                    ForEach(RuleCatalog.all.filter { $0.category == category }) { rule in
                        Toggle(isOn: Binding(
                            get: { settings.isEnabled(rule) },
                            set: { settings.setEnabled(rule, $0) }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(rule.name)
                                    RiskBadge(risk: rule.risk)
                                }
                                Text(rule.summary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                } header: {
                    Label(category.title, systemImage: category.systemImage)
                }
            }

            Section {
                Button("Restore Default Rules") { settings.resetRules() }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - General

private struct GeneralSettings: View {
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        Form {
            Section {
                Toggle("Launch Whippet at login", isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { settings.setLaunchAtLogin($0) }
                ))
                if settings.launchAtLoginNeedsApproval {
                    Text("Allow Whippet in System Settings › General › Login Items.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                if let error = settings.launchAtLoginError {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
            } footer: {
                Text("Works best when Whippet.app is in your Applications folder.")
                    .foregroundStyle(.secondary)
            }

            Section("About") {
                LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—")
                Link("Source on GitHub", destination: URL(string: "https://github.com/exploIF/whippet")!)
            }
        }
        .formStyle(.grouped)
        .onAppear { settings.refreshLaunchAtLogin() }
    }
}
