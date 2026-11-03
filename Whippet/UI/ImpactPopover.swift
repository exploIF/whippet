import SwiftUI

/// Explains what removing an item means, using the on-device model when available.
struct ImpactPopover: View {
    @Environment(ImpactExplainer.self) private var explainer
    let item: ScanItem

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(item.projectName.map { "\($0) · \(item.rule.name)" } ?? item.rule.name)
                    .font(.headline)
                Spacer()
                RiskBadge(risk: item.rule.risk)
            }
            Text("\(item.size.fileSize) · \(item.url.tildePath)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            Divider()

            content
        }
        .padding()
        .frame(width: 340)
        .onAppear { explainer.explain(item) }
    }

    @ViewBuilder
    private var content: some View {
        switch explainer.state(for: item) {
        case .generated(let impact):
            impactView(summary: impact.summary, consequences: impact.consequences, regeneration: impact.regeneration)
            aiFooter
        case .generating(let partial):
            impactView(summary: partial?.summary, consequences: partial?.consequences, regeneration: partial?.regeneration)
            HStack(spacing: 6) {
                ProgressView().controlSize(.mini)
                Text("Thinking on-device…").font(.caption).foregroundStyle(.secondary)
            }
        case .fallback(let reason):
            builtInView
            Label(reason, systemImage: "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        case nil:
            ProgressView().controlSize(.small)
        }
    }

    private func impactView(summary: String?, consequences: [String]?, regeneration: String?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let summary {
                Text(summary)
            }
            if let consequences, !consequences.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("If you remove it").font(.subheadline.weight(.semibold))
                    ForEach(Array(consequences.enumerated()), id: \.offset) { _, line in
                        Label(line, systemImage: "arrow.turn.down.right")
                            .labelStyle(BulletLabelStyle())
                    }
                }
            }
            if let regeneration {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Getting it back").font(.subheadline.weight(.semibold))
                    Text(regeneration)
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var builtInView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.rule.summary)
            VStack(alignment: .leading, spacing: 4) {
                Text("Getting it back").font(.subheadline.weight(.semibold))
                Text(item.rule.regenerateHint)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var aiFooter: some View {
        Label("Generated on-device by Apple Intelligence. AI can make mistakes, so check anything important.", systemImage: "apple.intelligence")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct BulletLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            configuration.icon
                .font(.caption)
                .foregroundStyle(.secondary)
            configuration.title
        }
    }
}
