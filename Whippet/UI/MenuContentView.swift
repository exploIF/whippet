import SwiftUI

struct MenuContentView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            scanControls

            if !model.items.isEmpty {
                Divider()
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(model.items) { item in
                            RawItemRow(item: item)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(maxHeight: 420)
            } else if !model.isScanning, model.lastScanDate != nil {
                Text("Nothing to clean up.")
                    .foregroundStyle(.secondary)
            }

            Divider()
            footer
        }
        .padding()
        .frame(width: 400)
    }

    private var header: some View {
        HStack {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 32, height: 32)
            VStack(alignment: .leading) {
                Text("Whippet").font(.headline)
                if !model.items.isEmpty {
                    Text("\(model.totalSize.formatted(.byteCount(style: .file))) reclaimable")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }

    private var scanControls: some View {
        HStack {
            if model.isScanning {
                ProgressView().controlSize(.small)
                Text(model.status ?? "Scanning…")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Cancel") { model.cancelScan() }
            } else {
                if let date = model.lastScanDate {
                    Text("Last scan \(date.formatted(.relative(presentation: .named)))")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Scan for caches and build artifacts.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Scan") { model.startScan() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
    }

    private var footer: some View {
        HStack {
            Text(rootsDescription)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(2)
                .help(model.projectRoots.map(\.path).joined(separator: "\n"))
            Spacer()
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
    }

    private var rootsDescription: String {
        let names = model.projectRoots.map { ($0.path as NSString).abbreviatingWithTildeInPath }
        return names.isEmpty ? "No project folders found" : "Projects: " + names.joined(separator: ", ")
    }
}

/// Temporary row used until the categorised UI lands.
private struct RawItemRow: View {
    let item: ScanItem

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text(item.rule.name).fontWeight(.medium)
                if let project = item.projectName {
                    Text(project).foregroundStyle(.secondary)
                }
                Spacer()
                Text(item.size.formatted(.byteCount(style: .file)))
                    .monospacedDigit()
            }
            HStack {
                Text((item.url.path as NSString).abbreviatingWithTildeInPath)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                if let date = item.lastModified {
                    Text(date.formatted(.relative(presentation: .named)))
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    MenuContentView()
        .environment(AppModel())
}
