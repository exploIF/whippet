import SwiftUI

/// Header row for a category. Its items are laid out by the parent list so they can load lazily.
struct CategoryHeader: View {
    @Environment(AppModel.self) private var model
    let group: CategoryGroup

    var body: some View {
        let expanded = model.expandedCategories.contains(group.category)

        HStack(spacing: 8) {
            // Shows the native mixed state when only some items are selected.
            Toggle(sources: group.items.map(model.selectionBinding(for:)), isOn: \.self) {
                Text("Select all \(group.category.title)")
            }
            .toggleStyle(.checkbox)
            .labelsHidden()

            Button {
                withAnimation(.snappy(duration: 0.2)) { model.toggleExpanded(group.category) }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                    Image(systemName: group.category.systemImage)
                        .frame(width: 16)
                    Text(group.category.title)
                        .fontWeight(.semibold)
                    Text("\(group.items.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(group.totalSize.fileSize)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}
