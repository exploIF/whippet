import SwiftUI

struct MenuContentView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            switch model.screen {
            case .confirm, .cleaning:
                Divider()
                ConfirmCleanView()
            case .report:
                Divider()
                if let report = model.lastReport {
                    CleanupResultView(report: report)
                }
            case .results:
                resultsScreen
            }
        }
        .padding()
        .frame(width: 420)
    }

    // MARK: - Sections

    @ViewBuilder
    private var resultsScreen: some View {
        scanControls

        if !model.items.isEmpty {
            filterBar
            Divider()
            results
            Divider()
            selectionSummary
        } else if !model.isScanning, model.lastScanDate != nil {
            Text("Nothing to clean up.")
                .foregroundStyle(.secondary)
        }

        Divider()
        footer
    }

    private var header: some View {
        HStack {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 32, height: 32)
            VStack(alignment: .leading) {
                Text("Whippet").font(.headline)
                if !model.items.isEmpty {
                    Text("\(model.visibleSize.fileSize) reclaimable")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
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
                Button(model.lastScanDate == nil ? "Scan" : "Rescan") { model.startScan() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
    }

    private var filterBar: some View {
        @Bindable var model = model
        return HStack(spacing: 8) {
            Picker("Age", selection: $model.filter.age) {
                ForEach(AgeFilter.allCases) { Text($0.title).tag($0) }
            }
            Picker("Size", selection: $model.filter.minimumSize) {
                ForEach(SizeFilter.allCases) { Text($0.title).tag($0) }
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .controlSize(.small)
        .fixedSize()
    }

    @ViewBuilder
    private var results: some View {
        let groups = model.groups
        if groups.isEmpty {
            Text("No items match the filters.")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(groups) { group in
                        CategorySection(group: group)
                    }
                }
                .padding(.vertical, 2)
                .padding(.trailing, 6)
            }
            .frame(maxHeight: 440)
            .fixedSize(horizontal: false, vertical: true)
        }
        if model.hiddenCount > 0 {
            Text("\(model.hiddenCount) items hidden by filters")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private var selectionSummary: some View {
        let count = model.selectedItems.count
        return HStack {
            Text(count == 0 ? "Nothing selected" : "\(count) selected · \(model.selectedSize.fileSize)")
                .monospacedDigit()
            Spacer()
            Button("Review & Move to Trash…") { model.reviewCleanup() }
                .disabled(count == 0 || model.isScanning)
        }
        .font(.callout)
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
        let names = model.projectRoots.map(\.tildePath)
        return names.isEmpty ? "No project folders found" : "Projects: " + names.joined(separator: ", ")
    }
}

#Preview {
    MenuContentView()
        .environment(AppModel())
}
