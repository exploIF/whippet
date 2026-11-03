import SwiftUI

/// Final review before anything is moved to the Trash.
struct ConfirmCleanView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let items = model.pendingCleanup
        let cleaning: (done: Int, total: Int)? = if case .cleaning(let done, let total) = model.screen {
            (done, total)
        } else {
            nil
        }

        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Move \(items.count) \(items.count == 1 ? "item" : "items") to the Trash?")
                    .font(.headline)
                Text("\(model.pendingSize.fileSize) will be freed once you empty the Trash.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            ForEach(model.runningToolWarnings, id: \.self) { warning in
                Label(warning, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if items.contains(where: { $0.rule.risk == .caution }) {
                Label("Some items are marked Caution and can't be regenerated.", systemImage: "exclamationmark.octagon.fill")
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(items) { item in
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.projectName.map { "\($0) · \(item.rule.name)" } ?? item.rule.name)
                                    .lineLimit(1)
                                Text(item.url.tildePath)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .textSelection(.enabled)
                            }
                            Spacer(minLength: 8)
                            Text(item.size.fileSize)
                                .monospacedDigit()
                        }
                    }
                }
                .padding(.trailing, 6)
            }
            .frame(maxHeight: 320)
            .fixedSize(horizontal: false, vertical: true)

            Divider()

            HStack {
                if let cleaning {
                    ProgressView(value: Double(cleaning.done), total: Double(max(cleaning.total, 1)))
                    Text("\(cleaning.done) of \(cleaning.total)")
                        .font(.callout)
                        .monospacedDigit()
                } else {
                    Button("Cancel", role: .cancel) { model.cancelCleanup() }
                        .keyboardShortcut(.cancelAction)
                    Spacer()
                    Button("Move to Trash", role: .destructive) {
                        Task { await model.performCleanup() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
            }
        }
    }
}
