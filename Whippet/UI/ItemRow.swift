import AppKit
import SwiftUI

struct ItemRow: View {
    @Environment(AppModel.self) private var model
    let item: ScanItem

    var body: some View {
        let selected = model.isSelected(item)

        HStack(alignment: .top, spacing: 8) {
            Toggle("Select \(title)", isOn: model.selectionBinding(for: item))
                .toggleStyle(.checkbox)
                .labelsHidden()

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(title)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    RiskBadge(risk: item.rule.risk)
                    Spacer(minLength: 4)
                    Text(item.size.fileSize)
                        .monospacedDigit()
                }
                HStack(spacing: 6) {
                    Text(item.url.tildePath)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 4)
                    Text(ageText)
                        .layoutPriority(1)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { model.setSelected(item, !selected) }
        .help("\(item.rule.summary)\n\n\(item.rule.regenerateHint)")
        .contextMenu {
            Button("Reveal in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([item.url])
            }
            Button("Copy Path") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(item.url.path, forType: .string)
            }
        }
    }

    /// Project items show the project name; global caches show the rule name.
    private var title: String {
        if let project = item.projectName {
            "\(project) · \(item.rule.name)"
        } else {
            item.rule.name
        }
    }

    private var ageText: String {
        guard let date = item.lastModified else { return "age unknown" }
        return "modified " + date.formatted(.relative(presentation: .named))
    }
}
