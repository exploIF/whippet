import AppKit
import SwiftUI

struct CleanupResultView: View {
    @Environment(AppModel.self) private var model
    let report: CleanupReport

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !report.trashed.isEmpty {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Moved \(report.trashed.count) \(report.trashed.count == 1 ? "item" : "items") to the Trash")
                            .font(.headline)
                        Text("Empty the Trash to free \(report.freedSize.fileSize).")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                } icon: {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                }
            }

            if !report.failures.isEmpty {
                Label("\(report.failures.count) \(report.failures.count == 1 ? "item was" : "items were") not moved",
                      systemImage: "xmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.red)

                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(report.failures) { failure in
                            VStack(alignment: .leading, spacing: 1) {
                                Text(failure.item.url.tildePath)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Text(failure.error.localizedDescription)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .frame(maxHeight: 200)
                .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            HStack {
                if !report.trashed.isEmpty {
                    Button("Open Trash") {
                        let trash = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".Trash")
                        NSWorkspace.shared.open(trash)
                    }
                }
                Spacer()
                Button("Done") { model.dismissReport() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
    }
}
