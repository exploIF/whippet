import SwiftUI

struct RiskBadge: View {
    let risk: CleanupRisk

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(risk.title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 1)
        .background(color.opacity(0.14), in: Capsule())
        .overlay(Capsule().strokeBorder(color.opacity(0.35), lineWidth: 0.5))
        .fixedSize()
        .help(risk.explanation)
    }

    private var color: Color {
        switch risk {
        case .safe: .green
        case .moderate: .orange
        case .caution: .red
        }
    }
}

extension Int64 {
    var fileSize: String { formatted(.byteCount(style: .file)) }
}

extension URL {
    var tildePath: String { (path as NSString).abbreviatingWithTildeInPath }
}
